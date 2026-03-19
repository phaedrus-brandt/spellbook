# Absorption Lifecycle

Standalone skills can be **absorbed** into umbrella skills to reduce budget consumption.
An umbrella consolidates related skills into one budget entry with reference-based routing.

## When to Absorb

- 3+ skills share a natural domain boundary (research, standards, delivery)
- Budget pressure requires consolidation
- Skills are frequently co-triggered

## How to Absorb

1. Create umbrella `SKILL.md` with routing table mapping intent → reference file
2. Copy each absorbed skill's body (minus frontmatter) → `references/{name}.md`
3. Move `scripts/`, `assets/`, existing `references/` into umbrella (merge, prefix if collisions)
4. Delete old skill directory
5. Run `./scripts/generate-index.sh`

## Budget Impact

Budget scales O(umbrellas), not O(skills). Adding sub-capabilities costs zero budget.
This is the primary economic argument for absorption.

## Canonical Examples

| Umbrella | Skills absorbed | Routing style |
|----------|----------------|---------------|
| `skills/design/` | 11 skills | Mode-based (Explore/Extend/Audit/Sprint) |
| `skills/debug/` | Dynamic domains | Argument routing (`/debug stripe`) |
| `skills/research/` | 4 skills | Intent + argument routing |
| `skills/craft-primitive/` | primitive + skill-builder + skill-creator | Intent → reference routing |

## Umbrella SKILL.md Pattern

```yaml
---
name: umbrella-name
description: |
  One-line covering all sub-capabilities.
  Trigger keywords from ALL absorbed skills.
argument-hint: "[sub-capability] [args]"
---
```

Body: routing table mapping intent → reference file, shared quality gates,
anti-patterns. Keep it under 150 lines.
