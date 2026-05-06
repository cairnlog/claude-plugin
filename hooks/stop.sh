#!/usr/bin/env bash
# CairnLog Stop hook (plugin wrapper).
# Two responsibilities, both fail-soft:
#   1. work-loop driver — re-feeds the AI when .claude/cairnlog-work-loop.local.md
#      indicates an active loop. Runs regardless of cairnlog auth state.
#   2. pattern auto-learning — records observed tool sequences via the
#      cairnlog-hook-stop binary. Requires the CLI installed + logged in.
#
# Stop hooks must read stdin once. We tee it so both stages can consume.

set -e

WORK_LOOP_HOOK="${CLAUDE_PLUGIN_ROOT}/skills/work-loop/hooks/stop-hook.sh"
WORK_LOOP_STATE_FILE=".claude/cairnlog-work-loop.local.md"

INPUT=$(cat)

if [[ -f "$WORK_LOOP_STATE_FILE" && -x "$WORK_LOOP_HOOK" ]]; then
  WORK_LOOP_OUTPUT=$(echo "$INPUT" | "$WORK_LOOP_HOOK" 2>/dev/null || true)
  if [[ -n "$WORK_LOOP_OUTPUT" ]]; then
    echo "$WORK_LOOP_OUTPUT"
    exit 0
  fi
fi

if ! command -v cairnlog-hook-stop >/dev/null 2>&1; then
  exit 0
fi

if [[ ! -f "${HOME}/.cairnlog/config.json" ]]; then
  exit 0
fi

echo "$INPUT" | exec cairnlog-hook-stop
