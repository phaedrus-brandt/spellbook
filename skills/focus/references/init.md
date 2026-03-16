# Focus Init

Generate a `.spellbook.yaml` manifest for a project that doesn't have one.

## Process

### 1. Scan Project Dependencies

Check these files for dependency signals:

| File | Parse For |
|------|----------|
| `package.json` | `dependencies`, `devDependencies` keys |
| `go.mod` | `require` blocks |
| `mix.exs` | `deps` function |
| `Gemfile` | `gem` calls |
| `requirements.txt` | package names |
| `pyproject.toml` | `[project.dependencies]` |
| `Cargo.toml` | `[dependencies]` |

### 2. Match to Collections

Use the detection patterns below to suggest collections:

| Signal | Collection |
|--------|-----------|
| `stripe`, `@stripe/stripe-js`, `stripity_stripe`, `btcpay` | payments |
| `next`, `react`, `vue`, `@sveltejs`, `nuxt`, `playwright`, `cypress` | web |
| `@anthropic-ai/sdk`, `anthropic`, `openai`, `langchain`, `llamaindex` | agent |
| `posthog-js`, `@posthog/react`, `posthog` | growth |

### 3. Always Include Core

Every project should have at least these skills:
- `debug` — universal debugging capability
- `autopilot` — delivery pipeline

Suggest but don't force:
- `groom` — if the project has GitHub issues
- `reflect` — if the project uses retro patterns
- `research` — if the project does web research

### 4. Generate Manifest

```yaml
# .spellbook.yaml
skills:
  - debug
  - autopilot
  - groom
collections:
  - web
  - payments
agents: []
```

### 5. Present for Confirmation

Show the user:
- What was detected (dependencies, signals)
- What collections matched
- The proposed manifest
- Ask: "Write this to .spellbook.yaml?"

Only write after explicit confirmation.

### 6. Run Sync

After writing the manifest, immediately run the sync flow to install
the declared primitives.
