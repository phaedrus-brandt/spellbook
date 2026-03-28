# Local CI via Dagger — kill the push-wait-read loop

Priority: high
Status: in-progress
Estimate: L

## Goal
Agent runs full CI locally in seconds before push. GitHub Actions becomes merge-gate only.

## Non-Goals
- Don't replace GitHub Actions entirely (keep as merge gate)
- Don't build a custom CI framework — use Dagger
- Don't change existing test suites

## Oracle
- [x] `dagger call check` runs all 7 quality gates locally and passes (11s)
- [x] `dagger call lint-shell` / `lint-yaml` / `lint-python` run linters individually
- [ ] GitHub Actions workflow simplified to merge-gate only (triggers on PR merge, not push)
- [ ] `/autopilot` pipeline calls local CI before push
- [ ] Self-healing: CI failure triggers repair agent that proposes fix

## Notes
- Dagger v0.18+ has native LLM integration — agents discover and use Dagger Functions as tools
- Solomon Hykes (Docker creator) is building this. Pipelines are Go/Python/TS code, not YAML
- Nx reports self-healing CI saves more dev time than caching. 2/3 of broken PRs get auto-fixes
- `act` (nektos) is a stopgap for running existing GH Actions locally, but Dagger is the target
- Research: https://dagger.io/deep-dives/agentic-ci/
- Research: https://dagger.io/blog/automate-your-ci-fixes-self-healing-pipelines-with-ai-agents/
