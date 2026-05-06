#!/usr/bin/env bash
# Standalone diagnostic for cairnlog:work-loop. No dependency on `cairnlog doctor`.
# Reports: state file presence, active flag, iteration, control-memory cancel value,
# task counts grouped by status and (for awaiting_human) by blocking strength.
# Exits non-zero when no active loop is detected (composes in shell pipelines).

set -e

STATE_FILE=".claude/cairnlog-work-loop.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "no active work-loop (state file absent)"
  exit 1
fi

read_state() {
  grep "^$1:" "$STATE_FILE" | head -1 | awk '{print $2}' | tr -d '"'
}

ACTIVE=$(read_state active)
ITERATION=$(read_state iteration)
PROJECT=$(read_state project_slug)

echo "state_file: $STATE_FILE"
echo "active: $ACTIVE"
echo "iteration: $ITERATION"
echo "project: $PROJECT"
echo "---"

# Defer to the existing CLI for cancel + counts
cairnlog tasks loop-status --output human 2>/dev/null || echo "cairnlog tasks loop-status failed"

[[ "$ACTIVE" == "true" ]] || exit 1
exit 0
