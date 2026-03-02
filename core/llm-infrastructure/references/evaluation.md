# LLM Evaluation & Testing

Test prompts, models, and RAG systems with Promptfoo.

## Quick Start
```bash
npx promptfoo@latest init
npx promptfoo@latest eval
npx promptfoo@latest view
npx promptfoo@latest redteam run
```

## Assertion Types
- **Functional**: `contains`, `equals`, `is-json`, `regex`
- **Semantic**: `similar`, `llm-rubric`, `factuality`
- **Performance**: `cost`, `latency`
- **Security**: `moderation`, `pii-detection`

## CI/CD Integration
```yaml
name: 'Prompt Evaluation'
on:
  pull_request:
    paths: ['prompts/**', 'src/**/*prompt*']
jobs:
  evaluate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: promptfoo/promptfoo-action@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          openai-api-key: ${{ secrets.OPENAI_API_KEY }}
```

## Red Team Security Testing
```yaml
redteam:
  purpose: "Customer support chatbot"
  plugins:
    - prompt-injection
    - jailbreak
    - pii:direct
    - pii:session
    - hijacking
    - excessive-agency
  strategies:
    - jailbreak
    - prompt-injection
```

## Suite Structure
```
evals/
├── golden/        # Must-pass tests (every PR)
├── regression/    # Full suite (nightly)
├── security/      # Red team tests
└── benchmarks/    # Cost/latency tracking
```
