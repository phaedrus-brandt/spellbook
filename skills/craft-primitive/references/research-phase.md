# Research Phase

**Mandatory for new skills.** A skill that restates what the model already knows is worthless.
The value of a skill is encoding knowledge the model DOESN'T have: specific processes,
hard-won best practices, integration gotchas, failure modes, repo-specific conventions.

## Run All Three Before Writing SKILL.md

1. **`/research`** — Find best practices, reference implementations, real-world patterns.
   - What do experienced practitioners know that isn't obvious?
   - What are the common failure modes and production gotchas?
   - What decisions seem arbitrary but have strong reasons?
   - What's the gap between "works in a tutorial" and "works in production"?
   - What's specific to the current repository's stack/domain combination?

2. **`/context-engineering`** — Design the skill's context architecture:
   - What goes in SKILL.md body (always loaded) vs references/ (on-demand)?
   - What's the progressive disclosure strategy?
   - What context does an agent need at decision time vs research time?

3. **`/harness-engineering`** — Ensure the skill works well in agent workflows:
   - How will the agent invoke this? What triggers loading?
   - What other skills does this chain with?
   - What feedback loops (tests, linters, CI) validate the skill's advice?

## The Bar

After reading the skill, an agent should make decisions a senior domain specialist
would approve — decisions it could NOT make from training data alone.

If the skill doesn't clear that bar, it's not specific enough.
