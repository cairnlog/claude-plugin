---
name: gate
description: Create and manage cairnlog decision gates (PreToolUse rules that allow/deny/ask/warn on tool calls), and review auto-learned tool patterns via the cairnlog CLI (or optional MCP).
when_to_use: User says "set a rule that...", "block me if...", "warn before X", "review observed patterns", "promote this pattern to a gate", or asks about regulating tool behavior across sessions. Does NOT cover regular memory CRUD — for that load `cairnlog:memorize`. Patterns should NEVER auto-promote to gates without explicit human confirmation.
---

# cairnlog:gate

Gates are stored as `gate`-typed memories with structured `metadata`. They are evaluated by the `PreToolUse` hook on every tool call. Patterns are auto-observed `pattern`-typed memories from the `Stop` hook — they document what the agent actually did, but never become rules until promoted by a human or an explicit decision.

## Gate model

A gate has four structured fields under `metadata`:

| Field | Values | Meaning |
| --- | --- | --- |
| `scope` | `tool` \| `file_path` \| `pattern` | What the rule matches against |
| `match` | string (glob or regex) | The pattern itself |
| `matchType` | `glob` \| `regex` | How `match` is interpreted (default `glob`) |
| `action` | `allow` \| `deny` \| `ask` \| `warn` | What the hook returns |

Plus top-level: `priority` (higher = evaluated first, default 100), `expiresAt` (optional ISO datetime), `content` = the human-readable reason the gate exists.

### Pattern-scope warning

`scope: pattern` forces the `PreToolUse` hook to run on **every** tool call (vs. `tool` / `file_path` which short-circuit). That re-introduces ~50–150 tokens of context per call. Avoid unless necessary; rewrite as `scope: tool` (e.g. `mcp__postgres_prod__*`) or `scope: file_path` (e.g. `**/production/**`). The CLI prompts to confirm before creating one — pass `--yes` only after explicit user OK.

## CLI (primary)

### Gates

```sh
# List
cairnlog gates list [--limit 20] [--project <slug>]

# Create
cairnlog gates create \
  --scope tool \
  --match "Bash" \
  --action ask \
  --reason "Always confirm shell commands" \
  [--match-type glob|regex] \
  [--priority 100] \
  [--expires 2026-12-31T00:00:00Z] \
  [--project <slug>] \
  [--yes]   # required for scope=pattern

# Delete
cairnlog gates delete <id> [--force] [--project <slug>]
```

### Patterns

```sh
cairnlog patterns list [--limit 20] [--project <slug>]
cairnlog patterns promote <pattern-id> [--project <slug>]   # interactive prompts
```

`patterns promote` walks you through `scope` / `match` / `matchType` / `action` / `reason` / `priority`, then writes a `gate` memory tagged `promoted-from-pattern` and back-links the pattern's `metadata.promotedToGateId`.

## Hook behavior

The `PreToolUse` hook calls `POST /rules/evaluate` per tool call. Mapping:

| Gate `action` | Claude Code permission decision |
| --- | --- |
| `allow` | Tool runs without prompt |
| `deny` | Tool blocked; user sees the gate's reason |
| `ask` | User prompted to confirm |
| `warn` | Notice surfaced; tool still runs |

Fail-safe: API unreachable → `ask` (never silent allow). Hook budget is 100ms — slow API also returns `ask`.

The `Stop` hook records observed tool sequences as `pattern` memories when 3+ tool calls happened since the last user prompt. Patterns *never* auto-promote.

## MCP tools (optional)

Gets unmounted on Claude account switch; CLI doesn't.

| Tool | CLI equivalent |
| --- | --- |
| `mcp__cairnlog__create_gate` | `cairnlog gates create` |
| `mcp__cairnlog__list_gates` | `cairnlog gates list` |
| `mcp__cairnlog__delete_gate` | `cairnlog gates delete` |
| `mcp__cairnlog__evaluate_gate` | (no CLI equivalent) — dry-run a tool call against ruleset |
| `mcp__cairnlog__list_patterns` | `cairnlog patterns list` |
| `mcp__cairnlog__suggest_gate_from_pattern` | `cairnlog patterns promote` (interactive prompts replace the suggestion+create_gate two-step) |

## Don't

- **Don't auto-promote patterns to gates.** That's how you get stuck rules. Always require explicit human confirmation.
- **Don't use `scope: pattern` casually.** It taxes every tool call. Rewrite as `tool` or `file_path` whenever the rule's intent allows.
- **Don't store the gate's reason in `tags`** — it goes in `--reason` (which becomes `content` and `metadata.reason`). Tags are for filtering.
- **Don't create gates for things `CLAUDE.md` already enforces.** Gates are for runtime regulation across sessions/teams, not project-local rules.

## Concurrency

Gates are memories — `update` calls follow the same optimistic concurrency rules as `cairnlog:memorize`. On 409, re-fetch via `cairnlog memories cat /<project>/gate/<id>` before retrying.
