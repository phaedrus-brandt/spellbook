# Talking to LLMs

LLMs are intelligent agents, not script executors. Talk to them like senior engineers.

## Anti-Patterns
- **Over-prescriptive**: Step-by-step runbooks that remove adaptability
- **Excessive hand-holding**: Exhaustive if/else trees
- **Defensive over-specification**: 10 IMPORTANT/WARNING/CRITICAL notes

## Good Patterns

### State the Goal, Not the Steps
```
Investigate production errors. Check all available observability.
Correlate with git history. Find root cause. Propose fix.
```

### Role + Objective + Latitude
```
You're a senior engineer reviewing this PR.    # Role
Find bugs, security issues, and code smells.   # Objective
Be direct. If it's fine, say so briefly.       # Latitude
```

## The Test
> "Would I give these instructions to a senior engineer?"

If you'd be embarrassed to hand a colleague a 700-line runbook, don't give it to the LLM either.
