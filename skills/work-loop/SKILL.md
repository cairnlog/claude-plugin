---
name: work-loop
description: Run an autonomous task loop against cairnlog. Reads tasks from cairnlog, executes ticket-by-ticket, halts on hard-blocked human questions, and continues until cancelled or exhausted. Driven by a Stop hook + sentinel token, mirroring the ralph-loop pattern.
when_to_use: User says "start work-loop", "run autonomous loop", "work through cairnlog tasks", or invokes `/cairnlog:work-loop`. Skip when the user wants a single task done — this is for iterating through a queue. For task frontmatter, blocking modes, and ask/answer schema details load `cairnlog:task`. For memory CRUD load `cairnlog:memorize`.
---

# cairnlog:work-loop

Autonomous task loop that executes cairnlog tasks one-by-one until cancelled, exhausted, or max iterations reached. Pattern mirrors ralph-loop: a local state file gates the Stop hook; the stop sentinel `<work-loop-stopped>` signals the hook to allow the session to end.

For task frontmatter schema, blocking modes (hard/soft/none), auto-resolve protocol, and the full ask/answer flow, load **`cairnlog:task`**. This skill only documents the loop driver.

## Starting the loop

Run `/cairnlog:work-loop`. The slash command invokes `${CLAUDE_PLUGIN_ROOT}/skills/work-loop/scripts/setup-work-loop.sh` under the hood.

Optional flags:
- `--project <slug>` — target project slug (defaults to active project in CLI config)
- `--max-iterations <n>` — cap iterations (0 = unlimited, default)
- `--prompt "<seed task title>"` — seed an initial task if none exists

## Pre-flight

Verify the loop can reach cairnlog:

```sh
cairnlog tasks list --limit 1 --output json
```

Exit 0 = authenticated and reachable. For a full end-to-end verification of all six HTTP endpoints and control-flow scenarios:

```sh
CAIRNLOG_PROJECT_ID=<throwaway-project-id> bun run work-loop:self-test
```

This hits the live API and cleans up its fixtures on completion.

## Per-iteration contract

Each iteration performs ONE ticket lifecycle:

1. **Cancel check**: `cairnlog tasks loop-status` (or `mcp__cairnlog__check_loop_cancel`).
   - If `cancel: true`: output `<work-loop-stopped>cancelled: <reason></work-loop-stopped>` and stop.

2. **Get next task**: `cairnlog tasks next`.

   Branch on `kind`:
   - `kind: "task"` — got an actionable task. Continue to step 3.
   - `kind: "exhausted"` — emit a stop sentinel matching the `status` (see table below) and stop.

3. **Mark in_progress**: update the task's frontmatter via `cairnlog memories edit`, set `status: in_progress`, increment `attempts`.

4. **Do the work**: use Read/Edit/Bash/etc to actually accomplish the task. Body has the description.

5. **Resolve the task**:
   - If completed: `status: done`. (Optional: append execution log entry to body.)
   - If you need a human's input: `cairnlog tasks ask <id> --question "..." --blocking <hard|soft> [--wait-until <iso>] --expected-version <n>`. Pick mode per `cairnlog-task` decision rubric.
   - If permanently stuck: `status: blocked`, document why in body.

6. **Optionally enqueue follow-ups**: create new task-tagged memories. Next iteration's `tasks next` picks them up if actionable.

7. **Do NOT output the stop sentinel after a successful work step** — let the Stop hook re-feed for the next iteration.

## Stop sentinels (exhausted statuses)

The Stop hook parses the last assistant message for `<work-loop-stopped>...</work-loop-stopped>`. Output it ONLY on a terminal condition:

| Trigger | Sentinel content |
| --- | --- |
| `kind: "exhausted"`, `status: "all_awaiting_human_hard"` | `<work-loop-stopped>awaiting_human: <count> hard-blocked task(s) — <one-line summary of first 3 questions></work-loop-stopped>` |
| `kind: "exhausted"`, `status: "all_awaiting_human_soft_pending"` | `<work-loop-stopped>awaiting_human: all soft-blocked, soonest at <wait_until></work-loop-stopped>` |
| `kind: "exhausted"`, `status: "stalled_in_progress"` | `<work-loop-stopped>stalled: <count> task(s) in_progress with no resolvable pending work</work-loop-stopped>` |
| `kind: "exhausted"`, `status: "all_blocked"` | `<work-loop-stopped>deadlock: all tasks blocked</work-loop-stopped>` |
| `kind: "exhausted"`, `status: "all_done"` | `<work-loop-stopped>complete: all tasks done</work-loop-stopped>` |
| `kind: "exhausted"`, `status: "empty"` | `<work-loop-stopped>complete: no tasks</work-loop-stopped>` |
| Cancel signal | `<work-loop-stopped>cancelled: <reason></work-loop-stopped>` |

The pattern mirrors ralph-loop's `<promise>...</promise>`. The Stop hook (`hooks/stop-hook.sh`) parses the last assistant message and only allows session exit when this token appears.

## Cancel

From inside Claude Code:

```sh
/cairnlog:cancel-loop
```

From any shell (outside the session):

```sh
cairnlog memories cancel-loop [--reason "<text>"]
```

To resume: `cairnlog memories cancel-loop --undo`, then `/cairnlog:work-loop` again.

The cancel-loop **write** is HTTP+CLI only by design — never MCP — so the AI loop cannot cancel itself.

## Debugging

```sh
# Loop state
cairnlog tasks loop-status --output human
"${CLAUDE_PLUGIN_ROOT}/skills/work-loop/scripts/loop-status.sh"
cat .claude/cairnlog-work-loop.local.md       # active, iteration, session_id

# Stuck waiting?
cairnlog tasks list --status awaiting_human --output human
```

State file fields: `active`, `iteration`, `session_id`, `max_iterations`, `started_at`.
