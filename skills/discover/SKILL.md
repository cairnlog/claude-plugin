---
name: discover
description: Record findings, open questions, and assumptions in cairnlog while exploring a problem — before composing a plan. Notes are normal `context` memories tagged with the kind plus a `discovery/<uuid>` group tag, so they can be searched, filtered, and later promoted into a plan via `linkedFindingIds`.
when_to_use: User asks the agent to investigate, scope, scope, or "look into" something where the right plan isn't yet obvious. Also use proactively when the agent encounters non-obvious facts about the codebase that should outlive this conversation but are not durable enough for `error`/`logic`/`workaround` (the bread-and-butter memorize types). Skip for tactical observations that fit better as a task comment, or for things already in `git log` / `CLAUDE.md`.
---

# Discovery — recording what you learn before you plan

When the right plan isn't obvious yet, the agent should explore *and write down what it finds* so the eventual plan is grounded in evidence rather than guesswork. That's what discovery is for.

## Three kinds of notes

| Kind | Use for |
| --- | --- |
| `finding` | A concrete observation: how the code currently works, what a constraint actually requires, what a test reveals. Past-tense, factual. |
| `open-question` | Something the agent doesn't know yet and needs answered before deciding. |
| `assumption` | Something the agent is treating-as-true that *should be challenged* before proceeding. |

If you can't decide which kind applies, default to `finding` for observations and `assumption` for "I'm pretty sure …" statements.

## Tag scheme

Each note is a `type: context` memory tagged with:
- the kind (`finding` | `open-question` | `assumption`)
- a grouping tag `discovery/<uuid>` (slash separator — the existing `tagNameSchema` rejects colons)
- on the marker note only, an extra `discovery-marker` tag (so `discover list` can find distinct discoveries cheaply)

## Starting a discovery

```sh
cairnlog discover start --topic "should auth tokens rotate per-tab?"
```

Mints a uuid, writes the marker, prints the id. Subsequent notes need that id.

For agent-initiated flows there's also the slash command `/cairnlog:discover <topic>` which calls this and returns the id directly.

## Recording notes

```sh
cairnlog discover note --id <uuid> --kind finding --text "..."
cairnlog discover note --id <uuid> --kind open-question --text "..."
cairnlog discover note --id <uuid> --kind assumption --text "..."
```

Or via memory MCP using `store_memory` with `type: "context"` and `tags: ["finding", "discovery/<uuid>"]`. The CLI is safer because it picks the right tag scheme automatically.

## When to exit discovery

You're ready to compose a plan when:

1. **You have enough findings to draft phases.** Each phase should map to a coherent quality-gate boundary; if you can't articulate gates yet, you have more to discover.
2. **Open questions are answered or scoped.** An unresolved open-question that affects scope must be answered before approval, not after.
3. **Assumptions are either confirmed (promoted to findings) or scheduled to be tested in a phase.** Don't carry untested assumptions into approved plans.

When you exit, draft the plan (`cairnlog:plan`) with `linkedFindingIds` populated with the discovery uuids you used. The web SPA / `plans show` output displays the link so reviewers can read the discovery before approving.

## Don't over-discover

- **One sentence per note.** If you need a paragraph, you're processing, not recording. Process the conclusion in your head, write the conclusion as a finding.
- **Skip what's in git/log/CLAUDE.md.** Discovery notes are about your *understanding*, not about restating documented facts.
- **Don't record TODOs.** Use `cairnlog:task` for those.

## Promoting findings to memory

Some findings become durable lessons (`error`, `logic`, `workaround`). After the plan is done, the agent should look back at the discovery and promote any that should outlive this project — see `cairnlog:memorize` for the right type to use.

## Cross-references

- [`cairnlog:plan`](../plan/SKILL.md) — compose a plan from findings.
- [`cairnlog:memorize`](../memorize/SKILL.md) — promote durable findings into long-lived memory types.
- [`cairnlog:task`](../task/SKILL.md) — for tactical TODOs that don't need plan structure.
