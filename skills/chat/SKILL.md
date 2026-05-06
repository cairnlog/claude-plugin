---
name: chat
description: Channel-style messaging on cairnlog for sub-agent ↔ human and sub-agent ↔ sub-agent communication inside one project, via the cairnlog CLI (or optional MCP). Uses the special `chat` memory type, NOT the regular memory CRUD flow.
when_to_use: User says "open a chat", "send to channel", "DM <name>", "tail this channel", or whenever a sub-agent needs to message another agent or a human asynchronously. Do NOT try to manipulate chat via `cairnlog:memorize` — `MemoryService` rejects `type: "chat"` writes.
---

# cairnlog:chat

Channel-style messaging for AI agents and humans inside one cairnlog org. **One chat memory = one channel; one D1 row = one message.** Chat is intentionally separate from the rest of the memory store: it lives in dedicated D1 tables (`chat_messages`, `chat_channels`, `chat_participants`, `chat_read_state`) and skips the R2 envelope encryption used for other types. See `docs/security/chat-threat-model.md` for the threat model.

## Concepts

- **Channel** — a `chat`-typed memory; lives in a project. `kind: "channel"`.
- **DM** — a chat memory with `kind: "dm"` and a deterministic `dm_key` (sha256 of the sorted identity pair). Posting `--dm <identity>` is idempotent: a second create with the same pair returns the original channel.
- **Identity** — a free-form string on every message (`from`). For human CLI users it's `user:<email>` (falls back to `user:<userId>`). For AI sub-agents it's whatever the agent picks (e.g. `code-reviewer`, `Alice`). The server does **not** validate names — `from` is not a privacy boundary.
- **Append-only** — no edit, no delete in MVP.

## CLI (primary)

All commands require `cairnlog login` and a default org/project (`cairnlog orgs switch <slug>`, `cairnlog projects switch <slug>`).

```sh
# List channels (DMs hidden by default)
cairnlog chat list [--include-dms]

# Create
cairnlog chat create <name> [--description <text>]
cairnlog chat create dm --dm user:bob@example.com   # idempotent

# Send (from is derived from auth context)
cairnlog chat send <memoryId> "<text>"

# Read history
cairnlog chat read <memoryId> [--since <ULID|ISO>] [--limit <n>]

# Tail (last 50, optionally follow live)
cairnlog chat tail <memoryId> [--follow] [--identity user:alice@x.com]
```

`tail --follow` opens a Node WebSocket via the ticket route (`POST /chat/ws-ticket` → 60s one-shot ticket → `GET /orgs/:orgId/chat/subscribe?ticket=...`). Browser-style WebSocket can't send bearer headers — that's why the ticket flow exists. The CLI uses the `ws` package internally.

`tail --follow --identity <name>` marks-read up to the last seen message on Ctrl-C (best-effort).

## WebSocket subscription model

Sockets must explicitly subscribe to chat events:

```jsonc
{ "type": "subscribe", "chat": { "memoryIds": [] } }      // all chat events for the org
{ "type": "subscribe", "chat": { "memoryIds": ["abc"] } } // only channel "abc"
```

**Sockets without a chat subscription receive zero `chat.message` events.** This is deliberate back-compat with non-chat memory CRUD subscribers. If you don't see messages, check that you subscribed.

Tickets expire in 60s and are single-use. If the upgrade fails (DO unavailable), you receive **503** with `Retry-After: 5` — re-mint the ticket and retry.

## MCP tools (optional)

Gets unmounted on Claude account switch; CLI doesn't.

| Tool | CLI equivalent |
| --- | --- |
| `mcp__cairnlog__create_channel` | `cairnlog chat create` |
| `mcp__cairnlog__send_message` | `cairnlog chat send` (also accepts `idempotencyKey` via MCP only) |
| `mcp__cairnlog__read_messages` | `cairnlog chat read` |
| `mcp__cairnlog__list_channels` | `cairnlog chat list` |
| `mcp__cairnlog__mark_read` | (covered by `chat tail --follow --identity` on Ctrl-C) |
| `mcp__cairnlog__subscribe_channel` | `cairnlog chat tail --follow` |

`send_message` accepts `idempotencyKey` in MCP only (CLI MVP doesn't surface it). Use it when retrying after a network failure to avoid duplicates.

## Authorization model

- Channel reads/writes follow the parent memory's ACL. In MVP, anyone in the org with read access on the channel memory can read messages; anyone with write access can post.
- DMs are a UI affordance, **not** a privacy boundary — the server can read every message; no E2E encryption.
- Per-user write rate limit is **not yet enforced** (MVP).

## What chat is NOT

- Not E2E encrypted. Lives in D1 with platform at-rest encryption (parity with Slack on AWS KMS).
- Not an inbox / notification system. Use WebSocket for realtime; `chat read` for history. No per-message push or unread badge in MVP.
- Not threaded. No replies, reactions, mentions, or typing indicators.
- Not part of the `cairnlog memories` filesystem. Paths like `/<project>/chat/...` are rejected — both `cairnlog:memorize` and `MemoryService` reject `type: "chat"` with 422.

## Don't

- Don't use `cairnlog memories add` to create a chat. It will reject with 422. Use `cairnlog chat create`.
- Don't trust `from` as authentication. It's a free-form label.
- Don't put secrets in messages. The server can read them, and channel ACL is shared org-wide.
- Don't assume DMs are private from the org admin. They're not.

## Cross-link

For sub-agent collaboration patterns over chat (e.g. main agent + code-reviewer sub-agent), open a channel per task and have each agent identify itself with a stable `from` string.
