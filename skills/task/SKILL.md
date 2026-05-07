---
name: task
description: Work with cairnlog task-tagged memories — frontmatter schema, list/next/reorder, and async ask/answer flows — via the cairnlog CLI (or optional MCP). Tasks are memories with `tags: ["task"]` plus a YAML frontmatter block conforming to taskFrontmatterSchema.
when_to_use: User mentions "task", "queue", "ticket", "ask the human", or invokes the work-loop. Also when reading/creating/advancing/reordering/blocking on a task in any cairnlog project. For the autonomous loop driver itself load `cairnlog:work-loop`. For memory CRUD load `cairnlog:memorize`.
---

# cairnlog:task

Tasks are **memories with `tags: ["task"]`** whose body starts with a YAML frontmatter block conforming to `taskFrontmatterSchema` (`packages/shared/src/task-frontmatter.ts`). Any memory type works — `context` is conventional. The tag makes a memory a task; the schema validates how the loop can act on it.

## Task frontmatter schema

### Required

| Field | Type | Notes |
| --- | --- | --- |
| `tags` | `string[]` | Must include `"task"` |
| `title` | `string` | Non-empty |
| `status` | `pending`\|`in_progress`\|`done`\|`blocked`\|`awaiting_human`\|`cancelled` | |

### Optional

| Field | Type | Notes |
| --- | --- | --- |
| `priority` | `high`\|`medium`\|`low` | |
| `order` | `integer` | Smaller = earlier; absent = NULLS LAST |
| `parent` | `uuid` | Parent task id |
| `depends_on` | `uuid[]` | Task ids that must be `done` first |
| `attempts` | `int` | Default 0; incremented by `answer_human` |

### Async-question fields (set by `ask_human` / `answer_human`)

| Field | Type | Notes |
| --- | --- | --- |
| `question` | `string` | The question posed to the human |
| `answer` | `string` | Set by the human before calling `answer_human` |
| `blocking` | `hard`\|`soft`\|`none` | Blocking strength |
| `wait_until` | ISO datetime | `soft` only; auto-resolve deadline |
| `auto_resolved` | `boolean` | Set to `true` after AI auto-resolves a soft block |

### Plan-linkage fields (set by `expand_plan_to_tasks`)

| Field | Type | Notes |
| --- | --- | --- |
| `plan_id` | `uuid` | Id of the plan memory this task was expanded from |
| `phase_id` | `string` | Phase id (e.g. `"phase-1"`) within the plan body |
| `step_index` | `int >= 0` | Step ordinal within the phase |
| `is_phase_gate` | `boolean` | `true` for synthetic phase quality-gate tasks |

All four are present-or-absent together (mixing plan_id with no phase_id is rejected). When `is_phase_gate: true`, the task **must** have `blocking: "hard"` and start in `awaiting_human`. Phase-gate tasks transition to `done` only via human ack; the work-loop reads them as the halt signal between phases.

See [`cairnlog:plan`](../plan/SKILL.md) for the full plan → expand flow.

### Schema invariants

- `status: awaiting_human` requires both `question` AND `blocking`.
- `blocking: soft` requires `wait_until`.
- `blocking: hard` or `blocking: none` rejects `wait_until`.
- `is_phase_gate: true` requires `plan_id` + `phase_id`, `blocking: "hard"`, and `status` in `{awaiting_human, done}`.
- `plan_id`, `phase_id`, `step_index` must all be set together (or all absent).
- `awaiting_human` + `blocking: none` is non-blocking and remains actionable.
- `auto_resolved: true` requires `status !== awaiting_human`.

## CLI (primary)

```sh
# List
cairnlog tasks list [--status <s>] [--priority <p>] [--limit <n>] [--output json|porcelain]

# Highest-priority actionable task
cairnlog tasks next

# Batch reorder
cairnlog tasks reorder --input updates.json

# Cancel-flag probe
cairnlog tasks loop-status [--output human|json]

# Ask human (sets awaiting_human + question + blocking)
cairnlog tasks ask <task-id> \
  --question "<q>" \
  --blocking hard|soft|none \
  [--wait-until <iso>] \
  --expected-version <n>

# Answer human (consumes body's `answer` field, transitions back to pending)
cairnlog tasks answer <task-id> --expected-version <n>

# Human-only loop kill switch
cairnlog memories cancel-loop [--reason "..."] [--undo]
```

`reorder --input` reads JSON like:

```json
{
  "updates": [
    { "id": "<C-uuid>", "order": 1, "expectedVersion": 3 },
    { "id": "<B-uuid>", "order": 2, "expectedVersion": 1 }
  ]
}
```

## Choosing a `blocking` mode

| Mode | When to use | Loop behavior |
| --- | --- | --- |
| **hard** | Answer fundamentally changes the work; wrong guess wastes non-trivial effort. | Loop halts. Resumes only after `answer_human` with a non-empty `answer`. |
| **soft** (preferred) | AI can guess but human steer would be better. Pair with `wait_until`. | Loop auto-resolves past `wait_until`: sets `auto_resolved: true`, logs reasoning, continues. |
| **none** | Informational only; AI is confident enough to proceed. Log the question as a body note. | Loop never blocks. NOT usable with `ask` (schema rejects it). |

Decision rubric:

- **hard** — answer determines the entire implementation path. A wrong assumption forces a rewrite.
- **soft** — answer would improve quality but the AI can make a reasonable default choice. Default `wait_until`: 1–4h for in-session loops, 24h+ for cross-day or cross-team questions.
- **none** — the question is purely for the human's awareness. Write inline in the task body, not via `ask`.

### Examples

Hard block:

```yaml
---
tags: [task]
title: Migrate auth middleware to Better Auth
status: awaiting_human
question: Should we keep the legacy session table or drop it?
blocking: hard
---
```

Soft block:

```yaml
---
tags: [task]
title: Choose rate-limit strategy
status: awaiting_human
question: Redis sliding window or token bucket for the new API tier?
blocking: soft
wait_until: "2026-05-02T10:00:00Z"
---
```

Informational (`blocking: none`, never via `ask`):

```yaml
---
tags: [task]
title: Refactor database query layer
status: pending
depends_on: []
attempts: 0
---
Note: considered using a query builder but went with raw SQL for performance.
```

## Auto-resolve protocol (`auto_resolve_hint: true`)

When `cairnlog tasks next` returns a task with `auto_resolve_hint: true`, the soft-block deadline has passed. The AI must:

1. Infer a best-effort answer using available context (don't wait for the human).
2. Append a log entry to the task body's "Execution log" section:
   `- <ISO timestamp> AI auto-resolved soft block: <one-line reasoning>`
3. Update the task via `cairnlog memories edit`:
   - `status: "pending"` (or directly `done` if work is complete in the same iteration)
   - `auto_resolved: true`
   - clear `blocking` and `wait_until`
   - keep `answer` field (debugging trail)
4. Continue the iteration normally.

Audit trail: body's log entry + frontmatter `auto_resolved: true` + the standard `update_memory` audit log.

## Ordering tasks (`order` + `reorder_tasks`)

- Smaller value = earlier execution.
- Absent (`undefined`) = NULLS LAST — executed after all explicitly ordered tasks.
- Ties broken by: `priority DESC` → `attempts ASC` → `createdAt ASC`.
- Negative values are valid (useful for "insert before everything" without renumbering).

`reorder` is fail-fast optimistic concurrency: on the first `expectedVersion` mismatch it aborts and returns `{status:"conflict", appliedIds, conflictId, currentVersion}`. The caller re-fetches and retries only the remaining updates.

## MCP tools (optional)

Gets unmounted on Claude account switch; CLI doesn't.

| Tool | CLI equivalent |
| --- | --- |
| `mcp__cairnlog__list_tasks` | `cairnlog tasks list` |
| `mcp__cairnlog__next_task` | `cairnlog tasks next` |
| `mcp__cairnlog__reorder_tasks` | `cairnlog tasks reorder --input` |
| `mcp__cairnlog__check_loop_cancel` | `cairnlog tasks loop-status` |
| `mcp__cairnlog__ask_human` | `cairnlog tasks ask` |
| `mcp__cairnlog__answer_human` | `cairnlog tasks answer` |
| — (intentionally absent in MCP) | `cairnlog memories cancel-loop` |

The cancel-loop **write** is HTTP+CLI only by design — never MCP. This prevents the AI loop from cancelling itself.

## Concurrency

All mutating calls (`ask`, `answer`, `reorder`, cancel-loop write) require `expectedVersion`. On HTTP 409:

1. Re-fetch: `cairnlog memories cat /<project>/<type>/<id>`.
2. Inspect new version + content.
3. Re-run with the fresh `version`.

Never re-run the same write blindly — your edit may no longer apply.

For `reorder` partial-apply, the response includes `appliedIds`. Rebuild remaining updates (only non-applied IDs plus the conflicting ID at its new version) and retry.

## Pre-flight check

Before running `/cairnlog:work-loop` for the first time on a project:

```sh
bun run work-loop:self-test
```

Required env: `CAIRNLOG_API_URL`, `CAIRNLOG_API_KEY`, `CAIRNLOG_ORG_ID`, `CAIRNLOG_PROJECT_ID`. Hits the live API end-to-end and cleans up its fixtures. See `apps/cli/docs/work-loop.md`.

## Don't

- Don't use `cairnlog tasks ask` with `--blocking none` — schema rejects it. Put informational notes inline in the task body.
- Don't auto-cancel the loop from MCP — there's no tool for it by design. Cancel via `cairnlog memories cancel-loop`.
- Don't overwrite a task's `attempts` manually unless you understand the side effects on the loop's auto-resolve heuristics.

## Cross-link

For the loop driver itself (Stop hook, sentinel, `/cairnlog:work-loop` slash command), load `cairnlog:work-loop`.
