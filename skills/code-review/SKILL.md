---
name: code-review
description: |
  Parallel multi-agent code review. Launch reviewer team, synthesize findings,
  auto-fix blocking issues, loop until clean.
  Use when: "review this", "code review", "is this ready to ship",
  "check this code", "review my changes".
  Trigger: /code-review, /review, /critique.
argument-hint: "[branch|diff|files]"
---

# /code-review

Launch a parallel team of reviewers. Synthesize findings. Fix blocking issues
automatically. Loop until clean or escalate to human.

## Workflow

Launch 3-5 subagents to review changes from distinct perspectives. Ousterhout, Grug, and Carmack are great choices, generally. You may want to pick others, or define your own ad-hoc, that are more specifically focused on the current repo and the changes being reviewed.

Collect all verdicts. Deduplicate overlapping concerns. Rank by severity.

If the change has user-facing components, verify the implementation actually works — not just that it reads well.

If live verification fails, it's a blocking issue — treat as Don't Ship.

**Any Don't Ship** → spawn a builder sub-agent for each blocking concern, giving it the specific file:line and fix instruction. Builder fixes, runs tests. Then re-review (return to step 2). Max 3 iterations.

### Plausible-but-Wrong Patterns

LLMs optimize for plausibility, not correctness. Reviewers must actively hunt for code that *looks right* but isn't:
- Wrong algorithm complexity (O(n²) where O(log n) is needed)
- Unnecessary abstractions (82K lines vs 1-line solution)
- Stub implementations that pass tests but don't actually work
- "Specification-shaped" code — right module names, wrong behavior
- Missing invariant checks that only matter at scale

## Simplification Pass

After review passes, if diff > 200 LOC net:
- Look for code that can be deleted
- Collapse unnecessary abstractions
- Simplify complex conditionals
- Remove compatibility shims with no real users

## Gotchas

- **Self-review leniency:** Models consistently overrate their own work. Reviewers must be separate sub-agents, not the builder evaluating itself.
- **Reviewing the whole codebase:** Review the diff, not the repo. `git diff main...HEAD` is the scope.
- **Skipping the bench:** Running only the critic misses structural issues. The philosophy agents add perspectives the critic doesn't cover.
- **Treating all concerns equally:** Blocking issues (correctness, security) gate shipping. Style preferences don't.
