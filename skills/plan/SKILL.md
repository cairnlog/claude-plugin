---
name: plan
description: Compose, approve, and expand cairnlog plans (overview / phases-with-quality-gates / steps as atomic commits) via the cairnlog CLI or MCP. Plans are first-class memories with status draft|approved|in_progress|done; once approved, they expand into work-loop tasks the autonomous loop can execute.
when_to_use: User says "draft a plan", "make a plan", "plan this feature", "let's plan the migration", "approve the plan", "expand into tasks", "start working on the plan". Also load proactively after a discovery flow has converged and the agent needs to materialize structured work, or when the user asks the agent to plan something non-trivial that warrants phase boundaries + quality gates. Skip when the user wants a single ad-hoc task — use `cairnlog:task` instead.
---

# CairnLog plans

A plan is structured work: **overview** → **phases** (each with a quality gate) → **steps** (each a single atomic commit). Plans live in cairnlog as `type: plan` memories, encrypted body, with a denormalized `plan_status` column for fast filtering.

## Lifecycle

```
draft  →  approved  →  in_progress  →  done
  ^         |              |
  edit      expand         (work-loop iterates step tasks;
  freely    into tasks      pauses on each phase-gate task
            (idempotent)    until a human acks)
```

- **draft**: body is freely editable. AI proposes, human reviews.
- **approved**: one-way transition. Body frozen. Ready to expand.
- **in_progress**: set by `expand` automatically. Work-loop is consuming the tasks.
- **done**: terminal. (Currently set manually; future v2 may auto-flip when all tasks are done.)

## Plan body grammar

```yaml
overview: "One paragraph: what + why."
successCriteria:
  - "Concrete, observable signal that the plan is done"
  - "Each criterion should be checkable post-hoc"
phases:
  - id: "phase-1"
    name: "Schema foundation"
    qualityGate: "lint + typecheck + test green workspace-wide; code-reviewer pass; simplify applied"
    steps:
      - id: "1.1"
        title: "Add plan schemas to shared"
        description: "Optional longer description"
        commitMessage: "feat(shared): add plan schemas (overview, phases, steps, status)"
      - id: "1.2"
        title: "..."
status: "draft"
linkedFindingIds: []
```

Phase id and step id must be unique (within the phase, for steps).

## When to use

- **Use a plan** when the work spans more than a single commit, has natural phase boundaries (where you'd want quality gates), and benefits from human approval before execution starts.
- **Skip the plan** for a one-off task: use `cairnlog tasks ...` directly via `cairnlog:task`.
- **Always plan** when launching `/cairnlog:work-loop` against a non-trivial change. The loop consuming an unplanned queue is fine for repetitive work but not for stage-gated migrations.

## Drafting a plan

The recommended flow uses **MCP** (lower latency, structured output):

```
mcp__cairnlog__create_plan({
  projectId: "<project-id>",
  title: "Migrate auth layer to Better Auth",
  body: { /* full plan body per the grammar above */ }
})
```

Or via CLI:

```sh
cairnlog plans create --input ./plan.json
```

Where `plan.json` is `{ "title": "...", "body": { ... } }`.

## Approval

The human reviews via `cairnlog plans show <id>` (or the web UI). When ready:

```
mcp__cairnlog__approve_plan({ projectId, planId, expectedVersion })
```

```sh
cairnlog plans approve <id> --expectedVersion <n>
```

Approval is **one-way**. To "un-approve", create a new plan or update steps before expanding.

## Expansion

Approved plans don't auto-expand — call `expand` explicitly so the human can preview the materialized task list before the loop starts iterating.

```
mcp__cairnlog__expand_plan_to_tasks({ projectId, planId })
```

```sh
cairnlog plans expand <id>
```

Each step becomes a `task` memory (`type: context`, `tags: ["task"]`) with `plan_id`, `phase_id`, `step_index` in its frontmatter. Between phases, a synthetic **phase-gate task** is inserted (`is_phase_gate: true`, `awaiting_human`, `blocking: hard`, `depends_on` the previous phase's step ids). The work-loop halts at each gate; a human acks by answering the gate task.

`expand` is idempotent — re-running returns the existing task ids without creating duplicates.

## Linking discovery findings

If you ran a discovery first (`cairnlog:discover`), pass the discovery ids in `body.linkedFindingIds`. This preserves the why behind the plan for later inspection:

```yaml
linkedFindingIds:
  - "8f29..."  # the discovery uuid
```

The web SPA's plan detail view surfaces these links so reviewers can see the originating findings.

## Editing approved plans

Body edits on approved plans are rejected (HTTP 422). Either:
- Soft-delete the plan and start fresh (orphaned tasks remain in the queue), or
- Edit the underlying step task frontmatter directly to course-correct, or
- Expand and let `update_plan` (title-only) refine messaging.

## Common mistakes

- **Phases without quality gates**: every phase must have a meaningful gate, or you're just listing chunks. The gate is what triggers human review during work-loop execution.
- **Steps that aren't atomic commits**: one step = one commit. If a step would need multiple commits to complete, split it.
- **Skipping discovery**: if you don't know enough to draft good phases, start with `/cairnlog:discover` first.
- **Approving and walking away**: someone needs to acknowledge phase gates as the loop progresses, or the loop just halts. Plan for that.

## Cross-references

- [`cairnlog:discover`](../discover/SKILL.md) — record findings before composing a plan.
- [`cairnlog:work-loop`](../work-loop/SKILL.md) — run the autonomous loop against expanded tasks.
- [`cairnlog:task`](../task/SKILL.md) — task frontmatter schema (incl. plan linkage fields).
