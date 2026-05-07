---
description: Start a cairnlog discovery — record findings/open-questions/assumptions before composing a plan
argument-hint: "<topic>"
---

# /cairnlog:discover

Start a discovery for the given topic. The agent will:

1. Mint a discovery uuid via `cairnlog discover start --topic "$ARGUMENTS"`.
2. Load the `cairnlog:discover` skill for the recording grammar.
3. Begin exploring the codebase / documentation / existing memories.
4. Record findings, open-questions, and assumptions as it goes via `cairnlog discover note --id <uuid> --kind ... --text "..."`.

When the picture is clear, exit discovery by composing a plan with `/cairnlog:plan-from-findings`. The plan should set `linkedFindingIds` to the discovery uuid(s) so reviewers can trace the why.

**When to use**: the user asks the agent to investigate, scope, or "look into" something where the right plan is not yet obvious.

**When NOT to use**: simple TODOs (use `cairnlog:task`), ad-hoc memory writes (use `cairnlog:memorize`), or tasks already covered by an approved plan.
