---
name: cli
description: Comprehensive reference for the `cairnlog` CLI binary — install/upgrade, auth, org/project switching, doctor/status/sync, and the full subcommand surface map. This is a reference-only skill; the agent loads it when it needs an exhaustive flag list, never via slash command.
when_to_use: When the agent needs the full CLI surface (every subcommand and flag) instead of the curated set in cairnlog:memorize/gate/chat/task. Also when bootstrapping a new machine, debugging hooks, or the user asks "how do I run this from a script". Skip when the focused skills already cover the operation.
user-invocable: false
---

# cairnlog:cli

The `cairnlog` CLI is the **primary** interface for cairnlog. MCP is an optional latency optimization that gets unmounted when you switch Claude accounts; CLI doesn't.

This skill is the comprehensive command-surface map. For semantic guidance on a specific area, prefer the focused skills:

- Memorize: `cairnlog:memorize`
- Gates / patterns: `cairnlog:gate`
- Chat: `cairnlog:chat`
- Tasks: `cairnlog:task`
- Work-loop: `cairnlog:work-loop`

## Bootstrap

### Install

```sh
curl -fsSL https://api.cairnlog.com/cli/install | sh
```

The installer:
- Writes to `$HOME/.cairnlog/`.
- Verifies SHA256 against the manifest.
- Creates a `cairnlog` symlink in a directory on `PATH`.
- Re-run anytime to upgrade.

The install endpoint and manifest are rate-limited (30/min); tarballs are immutable and cached. Set `CAIRNLOG_API` to point at a non-prod environment.

### Auth + context

```sh
cairnlog login                      # GitHub OAuth
cairnlog status                     # show user, default org, default project
cairnlog logout
```

After login, set defaults:

```sh
cairnlog orgs list
cairnlog orgs switch <slug>         # sets defaultOrgId in ~/.cairnlog/config.json

cairnlog projects list
cairnlog projects switch <slug>     # sets defaultProjectId
```

Most subcommands accept `--project <slug>` to override the default for that one call. If no default is set and no override is passed, the CLI exits non-zero with a clear message.

### Doctor / sync / upgrade

```sh
cairnlog doctor                     # check auth, hooks, API reachability
cairnlog sync                       # pull latest gates/patterns into local cache
cairnlog upgrade                    # in-place re-install of latest manifest
cairnlog install                    # install/refresh hook bins to .claude/settings.json
cairnlog uninstall                  # remove hook bins from .claude/settings.json
```

`install` here is *hook installation* (CLI binaries into `.claude/`), distinct from the curl install which sets up the CLI itself.

## Command tree

```
cairnlog
├── login | logout | status         # auth
├── orgs   { list, switch }
├── projects { list, switch }
├── memories { ls, cat, find, edit, add, search, get, update, delete, cancel-loop }
├── gates  { list, create, delete }
├── patterns { list, promote }
├── chat   { list, create, send, read, tail }
├── tasks  { list, next, reorder, loop-status, ask, answer }
├── install | uninstall | sync | upgrade | doctor
```

`memories search`, `memories get`, `memories update`, `memories delete` are **deprecated aliases** — they print to stderr and reject `--output json|porcelain`. Migrate scripts to `find`/`cat`/`edit`/(`delete` will be renamed to `rm`).

## CLI ↔ MCP equivalence

When MCP is mounted, you can substitute these tools for lower latency. After switching Claude accounts MCP gets unmounted — fall back to CLI.

| Capability | CLI | MCP tool |
| --- | --- | --- |
| Create memory | `cairnlog memories add --type <t> --title "<T>" --content "<c>" --tags a,b` | `store_memory` |
| Search memories (keyword) | `cairnlog memories find --query "<q>" [--type <t>]` | `search_memories` |
| Get one memory | `cairnlog memories cat /<project>/<type>/<id>` | `get_memory` |
| Update memory (whole field) | `cairnlog memories edit /<project>/<type>/<id> --set-content "<c>"` | `update_memory` |
| Update memory (find/replace) | `cairnlog memories edit /<project>/<type>/<id> --find <pat> --replace <repl>` | `update_memory` |
| Delete memory | `cairnlog memories delete <id>` | `delete_memory` |
| Server-side grep | `cairnlog memories find /<project>/<type>/ --content "<text>"` | (no MCP equivalent) |
| Create gate | `cairnlog gates create --scope <s> --match <m> --action <a> --reason "<r>"` | `create_gate` |
| List gates | `cairnlog gates list` | `list_gates` |
| Delete gate | `cairnlog gates delete <id>` | `delete_gate` |
| List patterns | `cairnlog patterns list` | `list_patterns` |
| Promote pattern → gate | `cairnlog patterns promote <id>` (interactive) | `suggest_gate_from_pattern` + `create_gate` |
| Create channel | `cairnlog chat create <name> [--description ...] [--dm <identity>]` | `create_channel` |
| Send message | `cairnlog chat send <memoryId> "<text>"` | `send_message` |
| Read messages | `cairnlog chat read <memoryId> [--since <c>] [--limit <n>]` | `read_messages` |
| List channels | `cairnlog chat list [--include-dms]` | `list_channels` |
| Mark read | `cairnlog chat tail --follow --identity <id>` (Ctrl-C marks read) | `mark_read` |
| Subscribe (live) | `cairnlog chat tail <memoryId> --follow` | `subscribe_channel` |
| List tasks | `cairnlog tasks list [--status ...] [--priority ...]` | `list_tasks` |
| Next actionable task | `cairnlog tasks next` | `next_task` |
| Reorder tasks | `cairnlog tasks reorder --input updates.json` | `reorder_tasks` |
| Cancel-loop probe | `cairnlog tasks loop-status` | `check_loop_cancel` |
| Cancel-loop write | `cairnlog memories cancel-loop [--reason "..."] [--undo]` | (intentionally absent in MCP) |
| Ask human | `cairnlog tasks ask <id> --question "<q>" --blocking <hard\|soft\|none> [--wait-until <iso>] --expected-version <n>` | `ask_human` |
| Answer human | `cairnlog tasks answer <id> --expected-version <n>` | `answer_human` |

## Output modes

Every new command supports `--output human|json|porcelain` (default `human`).

### JSON envelope

```json
{
  "envelopeVersion": 1,
  "schema": "memory.ls.memories.v1",
  "data": ...,
  "nextCursor": null,
  "warnings": []
}
```

`envelopeVersion` covers envelope shape; each command's payload carries its own `schema`. Adding a field = same schema name; removing/renaming bumps to `vN+1`.

Schemas: `memory.ls.projects.v1`, `memory.ls.types.v1`, `memory.ls.memories.v1`, `memory.get.v1`, `memory.find.v1`, `memory.grep.v1`, `memory.edit.v1`. CI conformance test: `apps/cli/src/schemas/conformance.test.ts`.

### Porcelain

Tab-separated, one record per line. Stable across releases for the same `schema` version. Use it for shell pipelines.

## Path grammar reminder

For `memories ls/cat/find/edit`:

```
/                                  active org's projects
/<project>/                        the type directories of <project>
/<project>/<type>/                 memories of <type>
/<project>/<type>/<id>             a single memory
/<project>/<type>/<id>@<version>   historical version
```

`<type>` ∈ `error | logic | workaround | context | gate | pattern`. `chat` is **not** a valid path — chat lives outside the filesystem grammar (use `cairnlog chat ...`).

`<project>` is a slug (`^[a-z0-9-]+$`), validated against the active org. Bare commands (`ls`, `cat`, `find` with no path) resolve to the active project — like a shell `cd`.

## Filter flags (`ls` / `find`)

| Flag | Meaning |
| --- | --- |
| `--tag <name>` | Only memories tagged `<name>` (client-side; pagination warning may show) |
| `--role active\|passive` | Filter by role |
| `--since <iso\|Nh\|Nd\|Nw\|Nmo\|Ny>` | Lower time bound |
| `--until <iso\|...>` | Upper time bound |
| `--time-field updatedAt\|createdAt` | Default `updatedAt` |
| `--query <text>` | Title/tags/description full-text |
| `--content <text>` | Server-side grep over decrypted content (3-char min, returns `truncated`/`truncatedReason`) |
| `--limit <n>` / `--cursor <s>` | Pagination |

Time shorthand: `h`/`d`/`w`/`mo`/`y`. `Nm` is rejected (ambiguous).

## Conflict-resolution playbook

CLI mutations are optimistic-concurrency on `version`. On HTTP 409:

1. The CLI prints the server's `currentVersion` and exits non-zero.
2. **Do not retry blindly.** Re-fetch with `cairnlog memories cat /<project>/<type>/<id> --output json`.
3. Re-derive your edit against the new content; retry.

For `--find`/`--replace`:
- **HTTP 409** = another writer landed first.
- **HTTP 422 (`no_match`)** = your pattern is gone from the new version. Read current content, re-derive.

## Environment variables

| Var | Purpose |
| --- | --- |
| `CAIRNLOG_API` | Override API base URL (default `https://api.cairnlog.com`) |
| `CAIRNLOG_API_URL` | Self-test target (work-loop self-test only) |
| `CAIRNLOG_API_KEY` | API key auth (alternative to GitHub OAuth) |
| `CAIRNLOG_ORG_ID` | Self-test org UUID |
| `CAIRNLOG_PROJECT_ID` | Self-test project UUID |
| `CI` / `NO_UPDATE_NOTIFIER` | Suppress the auto-update hint |

The CLI never modifies `~/.cairnlog/config.json` when run with `CAIRNLOG_API_KEY` — auth via env doesn't pollute the persisted config.

## Don't

- Don't use deprecated verbs (`memories search/get/update`) in scripts. They reject `--output json` and will be removed in v1.0.
- Don't construct paths with `chat` as the type segment. The path grammar rejects it.
- Don't use `cairnlog install` to bootstrap the CLI — that command installs *hook bins* into `.claude/`. Use the curl installer for the CLI itself.
- Don't bypass `--expected-version` on task mutations to avoid 409s. The 409 is your safety net against silent clobber.
