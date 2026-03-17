# Focus Init

Generate a `.spellbook.yaml` manifest for a project that doesn't have one.

## Process

### 1. Deeply Analyze the Project

Read everything available to understand what this project IS:

| Signal | Where |
|--------|-------|
| Project purpose, tech stack | `CLAUDE.md`, `README.md`, `AGENTS.md` |
| Dependencies | `package.json`, `go.mod`, `mix.exs`, `Gemfile`, `requirements.txt`, `Cargo.toml` |
| Directory structure | `ls` top-level dirs |
| Recent activity | `git log --oneline -20` |
| Existing skills | `.claude/skills/`, `.codex/skills/` |

Synthesize a 1-2 paragraph description of the project covering:
what it does, what tech it uses, what domains it touches.

### 2. Semantic Search for Relevant Primitives

Run the search script bundled with the focus skill:

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/search.py --project-dir . --top 20 --json
```

This automatically:
- Fetches the pre-computed embeddings index from GitHub (cached at `~/.cache/spellbook/`)
- Embeds the project context with Gemini Embedding 2
- Returns ranked matches across all indexed sources (spellbook + anthropics + openai + vercel + community)

If the search script fails (no GEMINI_API_KEY), fall back to:
```bash
curl -sfL https://raw.githubusercontent.com/phrazzld/spellbook/master/index.yaml
```
Then read the descriptions manually and use your own judgment to rank.

### 3. Curate with Discernment

For each candidate from the search results:

**Include if:**
- The skill addresses a concrete need this project has
- The project's tech stack matches the skill's domain
- The similarity score is > 0.65

**Exclude if:**
- No concrete use case in THIS specific repo
- The skill targets a technology not present in the project
- It's a domain skill for a domain this project doesn't touch

**Discernment over coverage.** 8 precisely-relevant primitives beats
25 that include noise. If a skill scored high but doesn't make sense,
trust your analysis of the project over the embedding score.

### 4. Handle External Sources

Skills from external sources use fully qualified names (FQN):

```yaml
skills:
  - debug                                        # phrazzld/spellbook (default)
  - anthropics/skills@frontend-design            # external source
  - vercel-labs/agent-skills@vercel-react-best-practices
  - Leonxlnx/taste-skill@design-taste-frontend
```

Unqualified names resolve to `phrazzld/spellbook`. Any other source
must use `owner/repo@skill-name` format.

### 5. Include Agents

Recommend agents alongside skills. The search covers both types.
Agents that match the project's needs go in the `agents:` section.

### 6. Generate Manifest

```yaml
# .spellbook.yaml
skills:
  - debug
  - autopilot
  - anthropics/skills@frontend-design
agents:
  - ousterhout
  - test-strategy-architect
```

### 7. Present for Confirmation

Show the user:
- What was detected (tech stack, dependencies, project purpose)
- Each recommended primitive with reasoning and score
- The proposed manifest

Ask: "Write this to .spellbook.yaml?"

Only write after explicit confirmation.

### 8. Run Sync

After writing the manifest, immediately run the sync flow to install
the declared primitives.
