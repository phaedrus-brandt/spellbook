# Cerberus Policy (Misty Step)

## Product posture

1. Cerberus Cloud remains a thin, opinionated wrapper around Cerberus OSS.
2. Keep user-exposed configuration minimal at first.
3. Preserve simplicity as a primary product value.

## Reviewer posture

1. Reviewer prompts should be adversarial by default:
- challenge assumptions
- search for edge cases
- look for regressions and hidden coupling
2. Multiple agentic reviewers are the adversarial layer.
3. Do not force rigid evidence templates; allow free-form findings + inline comments.

## Gate posture

1. Deterministic gates stay mandatory (lint/type/test/build/security).
2. Cerberus complements deterministic gates; it does not replace them.
3. Runtime safety (monitoring, Sentry, incident response, support channels) is a separate mandatory layer.

## Architecture ownership

1. Cerberus OSS owns review semantics and prompt strategy.
2. Cerberus Cloud owns orchestration, policy routing, quotas, billing, and integrations.
3. Avoid duplicating review logic in cloud.
