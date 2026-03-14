---
name: groom
description: |
  Interactive backlog grooming, backlog doctrine, and automated cleanup.
  Explore, brainstorm, research, synthesize into prioritized GitHub issues.
  Backlog strategy, ordering, pruning, agent-ready issue writing, overhaul.
  Use when: backlog session, issue grooming, sprint planning, backlog cleanup,
  backlog overhaul, rewriting tickets, reducing issue sprawl, agent-executable issues.
  Trigger: /groom, /backlog, /tidy, "groom the backlog", "clean up issues",
  "overhaul the backlog", "rewrite tickets", "agent-ready issues".
disable-model-invocation: true
---

# /groom

Orchestrate backlog management. Explore the product landscape with the user,
research best practices, validate with multi-model consensus, then synthesize
into a small, prioritized, agent-executable roadmap.

## Absorbed Skills

- `agent-backlog` — backlog doctrine, GitHub issue mechanics, agent-ready issue writing, overhaul workflow

## Philosophy

**Exploration before synthesis.** Understand deeply, discuss with user, THEN create issues.

**Research-first.** Every theme gets web research, cross-repo investigation, and codebase
deep-dive before scoping decisions are made.

**Multi-model validation.** Strategic directions pass through `/research thinktank` before locking.

**Quality gate on output.** Every created issue must score >= 70 on `/issue lint`.

**Write-through by default.** If grooming produces a clear backlog delta, apply it in GitHub
in the same turn. Do not stop at recommendations unless the user explicitly asks for draft-only output.

**Orchestrator pattern.** /groom invokes skills and agents, doesn't reimplement logic.

**Opinionated recommendations.** Don't just present options. Recommend and justify.

**Intent-first backlog.** Every issue must carry a clear Intent Contract that downstream
build/PR workflows can reference.

**Backlog is strategy, not storage.** Keep the backlog small, current, and legible.
Rough target: a couple dozen active issues, not 100+.

**Slash before adding.** When the backlog sprawls, default to merge/close/defer/rewrite
until the remaining set reflects the highest-priority themes.

**One roadmap, not many.** The backlog should read like the project's current plan,
not an archive of every bug, nit, brainstorm, review comment, or screenshot.

**Use judgment, not quotas.** The point is coherence and execution bandwidth, not
hitting an exact issue count.

## Org-Wide Standards

All issues MUST comply with `groom/references/org-standards.md`.
Load that file before creating any issues.

## Workflow

Run `/groom` in six phases:

1. **Context** — load or update `project.md`, check repo context freshness, read retro, capture user pain, audit backlog health
2. **Discovery** — launch parallel lanes and synthesize 3-5 strategic themes
3. **Research** — do web, cross-repo, and codebase research before scoping
4. **Exploration** — pitch options, recommend one, discuss, validate, then lock direction
5. **Synthesis** — reduce the backlog first, then create only missing strategic issues
6. **Artifact** — save a dated grooming plan and visual summary when useful

Synthesis default:
- issue edits, issue creation, issue closure, and label/milestone cleanup are part of the normal `/groom` deliverable
- if an audit or discussion yields actionable backlog changes, execute those GitHub writes without waiting for a follow-up ask
- fetch back written issues and verify labels, milestones, and body formatting after each write
- use `github-cli-hygiene` for all GitHub body writes

## References

### Workflow
- `references/interactive-workflow.md` — full Phase 1-4 flow
- `references/synthesis-workflow.md` — backlog reduction, issue creation, summaries, plan artifact, visual output

### Standards
- `references/org-standards.md` — required issue format, labels, milestones, readiness scoring
- `references/project-md-format.md` — `project.md` format
- `references/project-baseline.md` — baseline project standards

### Backlog Doctrine (absorbed from agent-backlog)
- `references/backlog-doctrine.md` — ordering, shaping, cadence, smells, definition of ready
- `references/github-issues.md` — platform primitives, hierarchy, intake, planning
- `references/agent-issue-writing.md` — writing agent-executable issue bodies, type-specific guidance
- `references/overhaul-workflow.md` — full backlog rebuild: audit, theme, reduce, rewrite, hierarchy

### Modes
- `references/backlog-health.md` — health dashboard procedure
- `references/tidy-procedure.md` — automated cleanup procedure

Default stance:
- explore before scoping
- reduce before adding
- keep one canonical issue where several shallow issues would otherwise survive
- create new issues only for genuine roadmap gaps

## Modes

### Interactive (default)
Full grooming session with exploration, research, and synthesis. Phases 1-6 above.

### Health Dashboard (`/groom --health`)
Quick read-only backlog assessment. Runs Phase 1 Step 5 only.
See `references/backlog-health.md`.

### Tidy (`/groom --tidy`)
Non-interactive automated cleanup. Lints, enriches, deduplicates, closes stale, migrates labels.
See `references/tidy-procedure.md`.

### Overhaul (`/groom --overhaul`)
Full backlog rebuild: audit, theme, reduce, rewrite, hierarchy, publish.
Non-interactive end-to-end restructuring when the backlog has drifted beyond tidy's reach.
See `references/overhaul-workflow.md`.

## Routing (from backlog doctrine)

When invoked for specific backlog concerns outside a full groom session:

- General backlog strategy, ordering, pruning, refinement:
  Read `references/backlog-doctrine.md`
- GitHub Issues, labels, milestones, sub-issues, dependencies, Projects:
  Read `references/github-issues.md`
- Writing or rewriting agent-ready issue bodies, acceptance criteria, boundaries:
  Read `references/agent-issue-writing.md`

## Related Skills

### Plumbing (Phase 2 + 5)
- `/audit [domain|--all]` — Unified domain auditor
- `/issue lint` — Score issues against org-standards
- `/issue enrich` — Fill gaps with sub-agent research
- `/issue decompose` — Split oversized issues
- `/retro` — Implementation feedback capture

### Planning & Design
| I want to... | Skill |
|--------------|-------|
| Full planning for one idea | `/shape` |
| Multi-model validation | `/research thinktank` |

### Standalone Domain Work
```bash
/audit quality        # Audit only
/audit quality --fix  # Audit + fix
/triage              # Fix highest priority production issue
```
