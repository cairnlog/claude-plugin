---
name: memorize
description: Read, write, search, edit, and delete cairnlog memories of type error/logic/workaround/context via the cairnlog CLI (or optional MCP). The bread-and-butter store/recall flow for non-obvious lessons that should survive across sessions.
when_to_use: User says "remember this", "save this for next time", "have we seen X before", "search memories for Y", "update the memory about Z". Also proactively when the agent encounters a recurring error, a non-obvious fix, an architectural decision, or wants to check prior context before non-trivial work. For gates load `cairnlog:gate`; for chat load `cairnlog:chat`; for task-tagged memories load `cairnlog:task`.
---

# cairnlog:memorize

The bread-and-butter store/recall API for non-chat, non-task memories. Five operations exposed via CLI (primary) and MCP (optional).

## Memory types covered

| Type | Body shape |
| --- | --- |
| `error` | A failure mode + trigger conditions. Lead with the symptom, not the fix. |
| `logic` | A working solution/recipe. Lead with the rule. |
| `workaround` | Temporary patch around an upstream bug. Include a "remove once X" condition. |
| `context` | Project-level facts: stakeholders, deadlines, constraints, "why we chose X". |

`gate` and `pattern` go through `cairnlog:gate`. `chat` goes through `cairnlog:chat`. Task-tagged memories go through `cairnlog:task`.

## CLI (primary)

The CLI exposes memories as a virtual filesystem. Path grammar:

```
/<project>/<type>/<id>
```

`<type>` for this skill: `error`, `logic`, `workaround`, `context`. (Plus `gate`/`pattern` covered by `cairnlog:gate`. `chat` is **not** a valid path — use `cairnlog:chat`.)

### Core operations

```sh
# Create
cairnlog memories add --type logic \
  --title "Retry strategy for D1 write conflicts" \
  --content "Use If-Match on PUT and surface 409 currentVersion. Why: D1 has no row locks." \
  --tags d1,retry,concurrency

# List
cairnlog memories ls /                                       # projects in active org
cairnlog memories ls /<project>/<type>/ --tag auth

# Read
cairnlog memories cat /<project>/<type>/<id>
cairnlog memories cat /<project>/<type>/<id>@<version>       # historical version

# Search title/tags/description
cairnlog memories find --query "retry" --since 7d

# Server-side grep over decrypted content (3-char min)
cairnlog memories find /<project>/logic/ --content "If-Match"

# Edit — find/replace (atomic server-side patch)
cairnlog memories edit /<project>/<type>/<id> --find <pat> --replace <repl>

# Edit — whole-field updates
cairnlog memories edit /<project>/<type>/<id> --set-content "<new content>"
cairnlog memories edit /<project>/<type>/<id> --set-content-file path.md
cairnlog memories edit /<project>/<type>/<id> --set-title "<t>" --set-tags a,b,c

# Delete
cairnlog memories delete <id>
```

Lead `content` with the rule/fact. For `context` memories, include **Why:** and **How to apply:** lines so future-you can judge edge cases.

### Filter flags (`ls` / `find`)

| Flag | Meaning |
| --- | --- |
| `--tag <name>` | Only memories tagged `<name>` |
| `--role active\|passive` | Filter by role |
| `--since <iso\|Nh\|Nd\|Nw\|Nmo\|Ny>` | Lower time bound |
| `--until <iso\|...>` | Upper time bound |
| `--time-field updatedAt\|createdAt` | Default `updatedAt` |
| `--query <text>` | Title/tags/description |
| `--content <text>` | Server-side grep (3-char minimum, returns `truncated`/`truncatedReason` on cap) |
| `--limit <n>` / `--cursor <s>` | Pagination |

Time shorthand: `h`/`d`/`w`/`mo`/`y`. `Nm` is rejected (ambiguous between minutes and months).

### Machine-readable output

```sh
cairnlog memories find --query "retry" --output json
cairnlog memories ls /<project>/<type>/ --output porcelain
```

JSON envelope:

```json
{
  "envelopeVersion": 1,
  "schema": "memory.ls.memories.v1",
  "data": ...,
  "nextCursor": null,
  "warnings": []
}
```

Schemas: `memory.ls.projects.v1`, `memory.ls.types.v1`, `memory.ls.memories.v1`, `memory.get.v1`, `memory.find.v1`, `memory.grep.v1`, `memory.edit.v1`. Adding a field = same schema name; removing/renaming bumps to `vN+1`. CI conformance test at `apps/cli/src/schemas/conformance.test.ts`.

## `edit` semantics in detail

- `edit --set-content` / `--set-content-file` / `--set-title` / `--set-tags` — whole-field updates via fetch + PUT-with-`If-Match`.
- `edit --find <pat> --replace <repl>` — sed-style. Defaults to **server-side atomic patch** (`POST /memories/:id/patch`), no client-side TOCTOU window.
- `--dry-run` — works on both paths; returns a unified diff without persisting.
- `--client-side` — escape hatch forcing fetch+PUT flow (for older servers without `/patch`).

## Conflict-resolution playbook

Two writers racing on `version`:

1. CLI fetches at `version=N`.
2. CLI submits with `If-Match: N` (PUT) or `version: N` (POST `/patch`).
3. If another writer landed first, server has `version=N+1` and rejects with **HTTP 409** + `{ error: { code: "version_mismatch", currentVersion: M } }`.
4. CLI surfaces conflict, exits non-zero. **Do not** re-run the same command without re-fetching.

Recommended retry:

```sh
cairnlog memories cat /<project>/<type>/<id> --output json    # observe new version
cairnlog memories edit /<project>/<type>/<id> --find ... --replace ... --dry-run
cairnlog memories edit /<project>/<type>/<id> --find ... --replace ...
```

For `--find`/`--replace`:
- **HTTP 409** = another writer modified the file. Re-fetch.
- **HTTP 422 (`no_match`)** = your pattern is no longer in the new version. Read current content and re-derive.

## MCP tools (optional latency optimization)

MCP gets unmounted when you switch Claude accounts; CLI doesn't. Only prefer MCP when latency matters and you've confirmed `mcp__cairnlog__*` is currently mounted.

| Tool | CLI equivalent |
| --- | --- |
| `mcp__cairnlog__store_memory` | `cairnlog memories add` |
| `mcp__cairnlog__search_memories` | `cairnlog memories find --query` |
| `mcp__cairnlog__get_memory` | `cairnlog memories cat` |
| `mcp__cairnlog__update_memory` | `cairnlog memories edit` |
| `mcp__cairnlog__delete_memory` | `cairnlog memories delete` |
| (no MCP) | `cairnlog memories find --content` (server-side grep) |

Same optimistic-concurrency rules apply: pass `expectedVersion`; on 409 re-fetch with `get_memory`.

## Legacy verbs (deprecated)

`memories search`, `memories get`, `memories update` still work but:

- Print `[deprecated]` to stderr.
- Reject `--output json` / `--output porcelain` (forces migration for machine-readable output).
- Will be removed in `cairnlog v1.0.0`.

| Legacy | Replacement |
| --- | --- |
| `memories search <q>` | `memories find --query <q>` |
| `memories get <id>` | `memories cat /<project>/<type>/<id>` |
| `memories update <id> ...` | `memories edit /<project>/<type>/<id> ...` |

## Don't

- Don't write memories restating the diff. The store is for facts that survive the diff.
- Don't store secrets, tokens, PII. Encrypted at rest but shared org-wide.
- Don't promote `pattern` → `gate` from this skill. Load `cairnlog:gate`.
- Don't operate on `chat` memories with these tools — they reject. Load `cairnlog:chat`.
