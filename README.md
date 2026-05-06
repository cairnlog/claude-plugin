# CairnLog Claude Code plugin

External cross-product AI memory and decision regulator for Claude Code. Bundles the skills, slash commands, hooks, and MCP integration for the cairnlog service at `https://api.cairnlog.com`.

## What you get

- **6 skills** for memory, gates, chat, tasks, the CLI, and an index entry skill — Claude loads them automatically when relevant.
- **3 slash commands**: `/cairnlog:work-loop`, `/cairnlog:cancel-loop`, `/cairnlog:help`.
- **3 hooks**: `UserPromptSubmit` (memory injection), `PreToolUse` (gate evaluation), `Stop` (auto-pattern + work-loop driver). All hooks fail-soft when the user is not logged in via the CLI.
- **MCP server** registration pointing at `https://api.cairnlog.com/mcp` (optional latency optimisation; the CLI is the primary interface).

## Prerequisites

Install the `cairnlog` CLI and authenticate:

```sh
curl -fsSL https://api.cairnlog.com/cli/install | sh
cairnlog login
cairnlog orgs switch <slug>
cairnlog projects switch <slug>
cairnlog doctor
```

Hooks read `~/.cairnlog/config.json` for the auth token. **If you skip `cairnlog login`, the hooks all fail-soft (silent `exit 0`)** and the plugin behaves as skills + commands + MCP only.

## Install

Add the plugin via the Claude Code marketplace UI, or clone and add manually:

```sh
git clone https://github.com/cairnlog/claude-plugin ~/.claude/plugins/cairnlog
```

## Layout

```
.claude-plugin/plugin.json    # manifest
.mcp.json                     # MCP server registration
skills/
  index/SKILL.md              # cairnlog:index — entry, points to other skills
  memorize/SKILL.md           # cairnlog:memorize — store/recall memories
  gate/SKILL.md               # cairnlog:gate — decision rules + patterns
  chat/SKILL.md               # cairnlog:chat — channel/DM messaging
  task/SKILL.md               # cairnlog:task — task frontmatter + ask/answer
  cli/SKILL.md                # cairnlog:cli — full CLI reference
  work-loop/                  # cairnlog:work-loop — autonomous task loop
    SKILL.md
    scripts/
      setup-work-loop.sh
      loop-status.sh
commands/
  work-loop.md                # /cairnlog:work-loop
  cancel-loop.md              # /cairnlog:cancel-loop
  help.md                     # /cairnlog:help
hooks/
  hooks.json                  # registers the three hooks below
  user-prompt-submit.sh       # injects relevant memories at prompt time
  pre-tool-use.sh             # evaluates next tool call against gates
  stop-hook.sh                # work-loop driver + pattern recording
```

## How upgrades work

The plugin is versioned via `plugin.json`. Pull from this repo or use the marketplace's update flow. The CLI (`cairnlog`) upgrades independently via `cairnlog upgrade`.

## License

MIT.
