---
description: Compose a cairnlog plan from accumulated discovery findings
argument-hint: "[--discovery <uuid>] [--title \"<plan title>\"]"
---

# /cairnlog:plan-from-findings

Draft a structured plan in cairnlog from the findings, open-questions, and assumptions accumulated during a discovery (or set of discoveries).

The agent will:

1. Load the `cairnlog:plan` skill for the plan body grammar.
2. Read the relevant discovery via `cairnlog discover show --id <uuid>` (if `--discovery` provided), or list active discoveries via `cairnlog discover list` and pick one.
3. Compose a plan body: overview, success criteria, phases (each with a meaningful quality gate), steps (each one atomic commit). Set `linkedFindingIds` to the discovery uuids that informed the plan.
4. Create the plan via `mcp__cairnlog__create_plan` (preferred) or `cairnlog plans create --input plan.json`.
5. Print the plan id + status, with next steps:
   - Review: `cairnlog plans show <id>`
   - Approve when ready: `cairnlog plans approve <id> --expectedVersion <n>`
   - Then expand: `cairnlog plans expand <id>` to materialize work-loop tasks.

**When to use**: discovery has converged and the user is ready to commit to a plan.

**Required first**: at least one open-question must be answered or scoped, and any load-bearing assumption must be either confirmed or scheduled to be tested in a phase. The `cairnlog:discover` skill has the exit checklist.
