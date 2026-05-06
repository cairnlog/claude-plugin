---
description: Cancel the active cairnlog work-loop
allowed-tools: ["Bash(cairnlog memories cancel-loop:*)", "Bash(test -f .claude/cairnlog-work-loop.local.md:*)", "Bash(rm .claude/cairnlog-work-loop.local.md)", "Read(.claude/cairnlog-work-loop.local.md)"]
disable-model-invocation: true
---

# Cancel Cairnlog Work-Loop

To cancel the active work-loop:

1. Check whether `.claude/cairnlog-work-loop.local.md` exists:
   ```bash
   test -f .claude/cairnlog-work-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"
   ```

2. **If NOT_FOUND**: Reply "No active cairnlog work-loop found."

3. **If EXISTS**:
   - Read `.claude/cairnlog-work-loop.local.md` to get the current iteration from the `iteration:` field.
   - Write the cancel signal to cairnlog (so any other session also sees it):
     ```bash
     cairnlog memories cancel-loop --reason "user invoked /cairnlog:cancel-loop"
     ```
   - Remove the local state file:
     ```bash
     rm .claude/cairnlog-work-loop.local.md
     ```
   - Report: "Cancelled cairnlog work-loop (was at iteration N)" using the iteration number you read.

If the `cairnlog` CLI is not installed or not authenticated, `cairnlog memories cancel-loop` will fail; in that case, deleting the local state file alone is sufficient to stop the loop in this session.
