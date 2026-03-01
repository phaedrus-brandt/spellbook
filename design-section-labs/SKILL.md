---
name: design-section-labs
description: |
  Build a visual HTML design catalogue for incremental refinement.
  Use when user likes current site and wants section-by-section upgrades (baseline vs variants),
  plus token/motion tuning, with a grid + compare + fullscreen viewer.
  Keywords: section lab, baseline, variant, refine, iterate, tokens, motion, compare, design catalogue
---

# Design Section Labs

Goal: preserve current identity; isolate deltas per section. No redesign.

## Output (HTML)

`.design-catalogue/`
- `index.html`: grid + compare + fullscreen modal viewer
- `styles/catalogue.css`: viewer chrome
- `proposals/NN-<lab>/preview.html`: lab page (baseline + variants)
- `proposals/NN-<lab>/styles.css`: lab tokens/styles

Each lab page MUST include:
- Baseline, Variant A, Variant B (same copy/structure)
- Design System Reference (type, palette, component states)
- Implementation Map (exact repo file paths + what to change)

## Templates

- `references/viewer-template.html` → `.design-catalogue/index.html`
- `references/catalogue.css` → `.design-catalogue/styles/catalogue.css`
- `references/section-lab-template.html` → `.design-catalogue/proposals/NN-<lab>/preview.html`

## Workflow

1. Snapshot current site. Write down invariants: fonts, palette, spacing, voice.
2. Choose 4-8 labs (typical: Hero, Approach, Projects, Contact, Tokens, Motion).
3. Generate lab previews:
   - Prefer Kimi for HTML/CSS execution if available.
   - Fallback: hand-author. Rule: isolate change; keep everything else fixed.
4. Build the catalogue viewer (use templates in `references/`).
5. Serve + open:
   - `python3 -m http.server 8888 --directory .design-catalogue`
   - `open http://localhost:8888`
6. Iterate: user picks variants → implement in code → update Implementation Map.

## Guardrails

- Preserve brand fonts/tokens unless the lab is explicitly a token-change.
- Accessibility: focus-visible, keyboard nav, reduced motion note.
- Prefer deep modules: one motion/tokens source of truth, not ad-hoc values.
