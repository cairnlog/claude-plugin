---
description: Start an autonomous cairnlog task loop in the current session
argument-hint: "[--prompt \"<seed>\"] [--project <slug>] [--max-iterations <n>]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/skills/work-loop/scripts/setup-work-loop.sh:*)"]
disable-model-invocation: true
---

# Cairnlog Work-Loop

Run the setup script to initialize the loop:

```!
"${CLAUDE_PLUGIN_ROOT}/skills/work-loop/scripts/setup-work-loop.sh" $ARGUMENTS
```

After setup completes, load the `cairnlog:work-loop` skill for the per-iteration contract, then begin iteration 1. Each iteration: cancel-check → next_task → mark in_progress → do work → resolve → optionally enqueue follow-ups.

The Stop hook (`${CLAUDE_PLUGIN_ROOT}/skills/work-loop/hooks/stop-hook.sh`) re-feeds you on every Stop event until you output `<work-loop-stopped>...</work-loop-stopped>` on a terminal condition (all done, cancelled, awaiting-hard, deadlock), or `cairnlog memories cancel-loop` is invoked from outside.

**Do not output the stop sentinel after a normal work step.** Only on the terminal conditions documented in the work-loop skill.
