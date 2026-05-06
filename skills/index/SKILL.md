---
name: index
description: External cross-product AI memory and decision regulator served at api.cairnlog.com. Entry index — points to focused sub-skills for memorize, gate, chat, task, CLI reference, and the autonomous work-loop. NOT the same thing as the local auto-memory under .claude/projects/.
when_to_use: User says "remember this", "have we seen X before", "save this for next time", "why did we do Y", "set a rule that...", "block me if...", "open a chat", "start work-loop". Also load proactively whenever the agent encounters a non-obvious lesson worth recording across sessions, or before non-trivial work to check prior decisions. Skip when the relevant fact is already in git history, current code, CLAUDE.md, or local .claude auto-memory.
---

# CairnLog — external AI memory & decision gates

CairnLog is an active AI behavior regulator. Three mechanisms:

1. **Context injection** — relevant memories pulled into the prompt at session start.
2. **Decision gates** — `PreToolUse` hooks evaluate tool calls against stored rules; `allow` / `deny` / `ask` / `warn`.
3. **Auto-learning** — `Stop` hooks observe tool patterns and store them as type `pattern` for later promotion.

The **`cairnlog` CLI** is the primary interface. MCP tools are an optional latency optimization, but they get unmounted when you switch Claude accounts — CLI doesn't.

## Sub-skills

| Skill | Use when |
| --- | --- |
| [`cairnlog:memorize`](../memorize/SKILL.md) | Writing/searching/reading/editing memories of type `error`/`logic`/`workaround`/`context`. The bread-and-butter store/recall flow. |
| [`cairnlog:gate`](../gate/SKILL.md) | Creating/listing/deleting `gate` rules; browsing `pattern` memories; promoting patterns to gates. |
| [`cairnlog:chat`](../chat/SKILL.md) | Channel-style messaging with sub-agents or humans (`chat` memory type, channels and DMs). |
| [`cairnlog:task`](../task/SKILL.md) | Task-tagged memories: frontmatter schema, listing/next/reorder, async ask/answer, blocking modes. |
| [`cairnlog:cli`](../cli/SKILL.md) | Full CLI cheat sheet — auth, orgs/projects, doctor, every subcommand. Reference-only; load when you need an exhaustive flag list. |
| [`cairnlog:work-loop`](../work-loop/SKILL.md) | Run an autonomous task loop via `/cairnlog:work-loop`. Driven by sentinel tokens and a Stop hook. |

## When to write a memory

Durable, non-obvious facts only:

| Type        | Use for                                                                              |
| ----------- | ------------------------------------------------------------------------------------ |
| `error`     | A failure mode + trigger conditions (NOT the fix — that's `logic`) |
| `logic`     | A working solution / recipe / approach to reuse |
| `workaround` | Temporary patch around an upstream bug, with a "remove once X" condition |
| `context`   | Project-level facts: stakeholders, deadlines, constraints, "why we chose X" |
| `gate`      | A rule that should block / warn on future tool calls (manual creation only) |
| `pattern`   | Auto-observed tool sequences. **Never auto-promote to `gate`** |
| `chat`      | Channel/DM messages. Goes through `cairnlog:chat`, not the memory CRUD flow |

**Don't write memories for:**

- Anything in `git log` / `git blame` / current code
- Ephemeral task state — use the conversation, plans, or task tools
- Things already in `CLAUDE.md` or local `.claude/projects/.../memory/`

## When to read memories

- Before non-trivial work in a project: search the topic
- When the user references prior work ("like we did last time")
- When a tool call surprises you (unexpected error, weird config) — search before re-investigating
- When a gate fires `ask` / `warn` — read the linked memory to understand the rule

## Hooks (configured by `cairnlog install`)

- `UserPromptSubmit` — injects relevant memories into prompt context
- `PreToolUse` — evaluates next tool call against active gates
- `Stop` — records observed tool patterns as type `pattern` (never auto-promotes)

API unreachable → hook returns `ask` (fail-safe, never silent allow). Run `cairnlog doctor` to diagnose.

## Don't

- Don't write memories restating what the diff says
- Don't auto-promote patterns to gates without user confirmation
- Don't bypass gates by reaching for shell when the MCP/CLI tool is gated — investigate the rule
- Don't store secrets, tokens, or PII. The store is encrypted at rest but shared org-wide

## Concurrency

Edits are optimistic-concurrency on `version`. On HTTP 409:

1. CLI/MCP returns server's `currentVersion`
2. **Re-fetch** before retrying — never re-run the same write blindly
3. On HTTP 422 (`no_match`) for `--find`/`--replace`, your pattern is gone from the new version

Per-skill conflict-resolution playbooks live in `cairnlog:memorize` and `cairnlog:task`.
