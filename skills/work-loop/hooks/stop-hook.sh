#!/usr/bin/env bash
# Stop hook for cairnlog:work-loop. Re-feeds the AI on each Stop event
# until <work-loop-stopped> token appears or max_iterations reached.
# Wired to Stop event ONLY (not SubagentStop) — sub-agent Stop must not
# re-enter the parent loop.

set -e

STATE_FILE=".claude/cairnlog-work-loop.local.md"

if ! command -v jq &>/dev/null; then
  echo "ERROR: cairnlog work-loop Stop hook requires jq. Stopping loop. Install jq to use this feature." >&2
  if [[ -f "$STATE_FILE" ]]; then
    sed -i.bak 's/^active: true/active: false/' "$STATE_FILE" && rm -f "${STATE_FILE}.bak"
  fi
  exit 0
fi

[[ -f "$STATE_FILE" ]] || exit 0

read_state() {
  grep "^$1:" "$STATE_FILE" | head -1 | awk '{print $2}' | tr -d '"'
}

mark_inactive() {
  sed -i.bak 's/^active: true/active: false/' "$STATE_FILE" && rm -f "${STATE_FILE}.bak"
}

INPUT=$(cat)
HOOK_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")

ACTIVE=$(read_state active)
SESSION_ID=$(read_state session_id)
ITERATION=$(read_state iteration)
MAX_ITERATIONS=$(read_state max_iterations)

[[ "$ACTIVE" != "true" ]] && exit 0

# First-touch session adoption: setup-work-loop writes "pending" because the
# real Claude Code session_id is not knowable from the spawning shell.
# Adopt the first hook event's session_id as authoritative; subsequent events
# from a different session are ignored to keep parallel sessions isolated.
if [[ "$SESSION_ID" == "pending" && -n "$HOOK_SESSION_ID" ]]; then
  sed -i.bak "s/^session_id: \"pending\"$/session_id: \"$HOOK_SESSION_ID\"/" "$STATE_FILE" && rm -f "${STATE_FILE}.bak"
  SESSION_ID="$HOOK_SESSION_ID"
fi

[[ -n "$HOOK_SESSION_ID" && -n "$SESSION_ID" && "$HOOK_SESSION_ID" != "$SESSION_ID" ]] && exit 0

extract_last_turn_text() {
  jq -sR '
    [ split("\n")[]
      | select(length > 0)
      | (fromjson? // empty)
      | select((.type // .message.role // .role) | IN("assistant", "user"))
    ]
    | . as $msgs
    | ([ range(0; length)
         | select(($msgs[.] | (.type // .message.role // .role)) == "user")
       ] | last // -1) as $lastUserIdx
    | $msgs[($lastUserIdx + 1):]
    | map(.message.content // .content // [])
    | map(if type == "string" then [{type:"text", text:.}]
          elif type == "array" then .
          else [] end)
    | flatten
    | map(select(.type == "text") | .text)
    | join("\n")
  ' "$1" 2>/dev/null || echo ""
}

turn_might_be_incomplete() {
  jq -sR '
    [ split("\n")[]
      | select(length > 0)
      | (fromjson? // empty)
      | select((.type // .message.role // .role) | IN("assistant", "user"))
    ]
    | last
    | (.type // .message.role // .role) == "user"
    and (
      (.message.content // .content // [])
      | (type == "array" and any(.[]; .type == "tool_result"))
    )
  ' "$1" 2>/dev/null | grep -q true
}

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  LAST_TURN_TEXT=$(extract_last_turn_text "$TRANSCRIPT_PATH")
  if [[ "$LAST_TURN_TEXT" != *"<work-loop-stopped>"* ]] && turn_might_be_incomplete "$TRANSCRIPT_PATH"; then
    for _attempt in 1 2 3 4 5 6; do
      sleep 0.15
      LAST_TURN_TEXT=$(extract_last_turn_text "$TRANSCRIPT_PATH")
      [[ "$LAST_TURN_TEXT" == *"<work-loop-stopped>"* ]] && break
      turn_might_be_incomplete "$TRANSCRIPT_PATH" || break
    done
  fi
  if [[ "$LAST_TURN_TEXT" == *"<work-loop-stopped>"* ]]; then
    mark_inactive
    exit 0
  fi
fi

if [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] && [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  mark_inactive
  exit 0
fi

NEXT_ITER=$((ITERATION + 1))
sed -i.bak "s/^iteration: $ITERATION$/iteration: $NEXT_ITER/" "$STATE_FILE" && rm -f "${STATE_FILE}.bak"

echo '{"decision":"block","reason":"continue cairnlog work-loop iteration '"$NEXT_ITER"'"}'
exit 0
