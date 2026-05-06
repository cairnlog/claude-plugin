---
description: Explain the cairnlog plugin and available commands
disable-model-invocation: true
---

# CairnLog plugin help

Please explain the following to the user, in their language if known:

## What this plugin does

CairnLog is **external cross-product AI memory and decision regulator**. The store lives at `https://api.cairnlog.com`. The CLI (`cairnlog`) is the primary interface; this plugin adds skills, slash commands, hooks, and an MCP registration on top of it.

## Skills loaded by this plugin

- `cairnlog:index` — entry index, points to the others
- `cairnlog:memorize` — store/recall durable memories
- `cairnlog:gate` — define `allow`/`deny`/`ask`/`warn` rules and review patterns
- `cairnlog:chat` — channel/DM messaging with sub-agents and humans
- `cairnlog:task` — task-tagged memories: schema, ask/answer flow, blocking modes
- `cairnlog:cli` — full CLI reference (loaded only by the agent on demand)
- `cairnlog:work-loop` — drive an autonomous task loop

## Commands

| Command | Purpose |
| --- | --- |
| `/cairnlog:work-loop` | Start an autonomous loop. Optional flags: `--prompt`, `--project`, `--max-iterations` |
| `/cairnlog:cancel-loop` | Cancel the active loop |
| `/cairnlog:help` | This message |

## Hooks (configured automatically)

- **UserPromptSubmit** — injects relevant memories into the prompt
- **PreToolUse** — evaluates the next tool call against active gates
- **Stop** — drives the work-loop, and records auto-patterns when authenticated

All three **fail-soft**: if the cairnlog CLI is not installed or `cairnlog login` has not been run, hooks silently exit 0 and the plugin behaves as skills + commands + MCP only.

## Setup checklist

```sh
curl -fsSL https://api.cairnlog.com/cli/install | sh   # install CLI
cairnlog login                                          # GitHub OAuth
cairnlog orgs switch <slug>
cairnlog projects switch <slug>
cairnlog doctor                                         # verify
```

## More

- Source: https://github.com/cairnlog/claude-plugin
- API: https://api.cairnlog.com
- Service: https://cairnlog.com
