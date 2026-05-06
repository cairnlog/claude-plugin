#!/usr/bin/env bash
set -euo pipefail

PROMPT=""
MAX_ITERATIONS=0
PROJECT_SLUG=""
STATE_FILE=".claude/cairnlog-work-loop.local.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --max-iterations)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --project)
      PROJECT_SLUG="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if ! command -v cairnlog &>/dev/null; then
  echo "ERROR: cairnlog CLI not found. Install: curl -fsSL https://api.cairnlog.com/cli/install | sh" >&2
  exit 1
fi

if ! cairnlog tasks list --limit 1 --output json &>/dev/null; then
  echo "ERROR: cairnlog is not authenticated or not reachable. Run: cairnlog login" >&2
  exit 1
fi

if [[ -z "$PROJECT_SLUG" ]]; then
  PROJECT_SLUG=$(cairnlog projects list 2>/dev/null | awk '/\(active\)/ {print $1; exit}')
  if [[ -z "$PROJECT_SLUG" ]]; then
    echo "ERROR: no active project. Run: cairnlog projects switch <slug>  or pass --project <slug>" >&2
    exit 1
  fi
fi

if [[ -n "$PROMPT" ]]; then
  EXISTING=$(cairnlog tasks list --output json 2>/dev/null | \
    jq -r --arg title "$PROMPT" \
    '.items[] | select(.title == $title) | select(.status == "pending" or .status == "in_progress") | .id' \
    2>/dev/null | head -1 || true)

  if [[ -z "$EXISTING" ]]; then
    TASK_BODY=$(printf -- "---\ntags:\n  - task\ntitle: %s\nstatus: pending\ndepends_on: []\nattempts: 0\n---\n" "$PROMPT")
    cairnlog memories store \
      --type context \
      --title "$PROMPT" \
      --tags task \
      --content "$TASK_BODY" \
      --output json &>/dev/null || true
  fi
fi

SESSION_ID="${CLAUDE_SESSION_ID:-pending}"

STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$STATE_FILE" <<EOF
---
active: true
iteration: 1
session_id: "$SESSION_ID"
max_iterations: $MAX_ITERATIONS
project_slug: "$PROJECT_SLUG"
started_at: "$STARTED_AT"
---

# cairnlog work-loop state

This file is managed by the cairnlog:work-loop skill.
Delete it or set \`active: false\` to stop the loop.
EOF

echo "Begin first iteration of cairnlog work-loop. Read the cairnlog:work-loop skill for the per-iteration contract, then start iteration 1 for project: $PROJECT_SLUG"
