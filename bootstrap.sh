#!/usr/bin/env bash
set -euo pipefail

# Spellbook Bootstrap
#
# Two modes:
#   LOCAL:  Symlinks harness dirs to a local spellbook checkout (fast, editable)
#   REMOTE: Downloads from GitHub (works on any machine without a checkout)
#
# Local mode is preferred. Remote is the fallback for fresh machines.
#
# Run: curl -sL https://raw.githubusercontent.com/phrazzld/spellbook/master/bootstrap.sh | bash

REPO="phrazzld/spellbook"
RAW="https://raw.githubusercontent.com/$REPO/master"

info()  { printf '\033[0;34m%s\033[0m\n' "$*"; }
ok()    { printf '\033[0;32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
err()   { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }

# --- Detect local spellbook checkout ---

SPELLBOOK=""
for candidate in \
  "$HOME/Development/spellbook" \
  "$HOME/dev/spellbook" \
  "$HOME/src/spellbook" \
  "$HOME/code/spellbook"; do
  if [ -d "$candidate/skills" ] && [ -f "$candidate/registry.yaml" ]; then
    SPELLBOOK="$candidate"
    break
  fi
done

# Allow override via environment
SPELLBOOK="${SPELLBOOK_DIR:-$SPELLBOOK}"

# --- Local mode: symlink ---

link_local() {
  local harness="$1"        # e.g. "claude"
  local harness_dir="$2"    # e.g. "$HOME/.claude"

  info "  Linking skills..."
  # Symlink each skill dir individually (not the whole skills/ dir)
  # so harnesses can have their own non-spellbook skills alongside
  mkdir -p "$harness_dir/skills"
  for skill_dir in "$SPELLBOOK/skills"/*/; do
    local name=$(basename "$skill_dir")
    ln -sfn "$skill_dir" "$harness_dir/skills/$name"
    ok "    $name → $harness_dir/skills/$name"
  done

  info "  Linking agents..."
  mkdir -p "$harness_dir/agents"
  for agent_file in "$SPELLBOOK/agents"/*.md; do
    local name=$(basename "$agent_file")
    ln -sfn "$agent_file" "$harness_dir/agents/$name"
    ok "    $name → $harness_dir/agents/$name"
  done

  # Link harness-specific configs if they exist
  local harness_config="$SPELLBOOK/harnesses/$harness"
  if [ -d "$harness_config" ]; then
    info "  Linking harness config..."
    case "$harness" in
      claude)
        # CLAUDE.md: symlink
        [ -f "$harness_config/CLAUDE.md" ] && \
          ln -sfn "$harness_config/CLAUDE.md" "$harness_dir/CLAUDE.md" && \
          ok "    CLAUDE.md"
        # hooks/: symlink individual scripts (preserve harness-local hooks)
        if [ -d "$harness_config/hooks" ]; then
          mkdir -p "$harness_dir/hooks"
          for hook in "$harness_config/hooks"/*.py "$harness_config/hooks"/*.sh; do
            [ -f "$hook" ] && ln -sfn "$hook" "$harness_dir/hooks/$(basename "$hook")"
          done
          ok "    hooks/"
        fi
        # settings.json: COPY, not symlink (Claude modifies it at runtime)
        [ -f "$harness_config/settings.json" ] && \
          cp "$harness_config/settings.json" "$harness_dir/settings.json" && \
          ok "    settings.json (copied)"
        ;;
      codex)
        [ -f "$harness_config/config.toml" ] && \
          mkdir -p "$harness_dir/config" && \
          ln -sfn "$harness_config/config.toml" "$harness_dir/config/config.toml" && \
          ok "    config.toml"
        ;;
      pi)
        if [ -d "$harness_config/context/global" ]; then
          mkdir -p "$harness_dir/agent"
          for f in "$harness_config/context/global"/*.md; do
            [ -f "$f" ] && ln -sfn "$f" "$harness_dir/agent/$(basename "$f")"
          done
          ok "    context/global/*.md"
        fi
        [ -f "$harness_config/settings.json" ] && \
          ln -sfn "$harness_config/settings.json" "$harness_dir/settings.json" && \
          ok "    settings.json"
        ;;
    esac
  fi
}

# --- Remote mode: download from GitHub ---

download_skill() {
  local skills_dir="$1"
  local name="$2"
  local target="$skills_dir/$name"
  mkdir -p "$target/references"

  curl -sfL "$RAW/skills/$name/SKILL.md" -o "$target/SKILL.md" || { err "Failed: $name/SKILL.md"; return 1; }

  # Best-effort: download references via GitHub API
  local refs
  refs=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references" 2>/dev/null | \
    python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='file']" 2>/dev/null) || true
  if [ -n "$refs" ]; then
    echo "$refs" | while read -r fname; do
      curl -sfL "$RAW/skills/$name/references/$fname" -o "$target/references/$fname" 2>/dev/null || true
    done
  fi

  ok "  $name → $target"
}

download_agent() {
  local agents_dir="$1"
  local name="$2"
  mkdir -p "$agents_dir"
  curl -sfL "$RAW/agents/$name.md" -o "$agents_dir/$name.md" || { err "Failed: agent $name"; return 1; }
  ok "  $name → $agents_dir/$name.md"
}

install_remote() {
  local skills_dir="$1"
  local agents_dir="$2"

  # Fetch registry.yaml for the skill/agent list
  local registry
  registry=$(curl -sfL "$RAW/registry.yaml") || { err "Failed to fetch registry.yaml"; return 1; }

  # Parse primitives from registry
  local parsed
  parsed=$(mktemp)
  echo "$registry" | python3 -c "
import re, sys
lines = sys.stdin.read().split('\n')
def extract(lines, path):
    depth, target_indent, items, capturing = 0, [None]*len(path), [], False
    for line in lines:
        if not line.strip() or line.strip().startswith('#'): continue
        indent, stripped = len(line)-len(line.lstrip()), line.strip()
        if depth < len(path):
            if stripped.startswith(path[depth]+':'):
                target_indent[depth] = indent; depth += 1
                if depth == len(path):
                    capturing = True
                    rest = stripped[len(path[-1])+1:].strip()
                    if rest.startswith('[') and rest.endswith(']'):
                        items = [v.strip() for v in rest[1:-1].split(',')]; break
                continue
        elif capturing:
            if indent <= target_indent[-1]: break
            if stripped.startswith('- '): items.append(stripped[2:].strip())
    return items
custom = extract(lines, ['global','skills','custom_install'])
standard = extract(lines, ['global','skills','standard'])
agents = extract(lines, ['global','agents'])
safe = re.compile(r'^[a-z0-9-]+\$')
for n in custom+standard+agents:
    if not safe.match(n): print(f'INVALID: {n}', file=sys.stderr); sys.exit(1)
print('CUSTOM_INSTALL=('+' '.join(custom)+')')
print('GLOBAL_SKILLS=('+' '.join(standard)+')')
print('GLOBAL_AGENTS=('+' '.join(agents)+')')
" > "$parsed" || { err "Failed to parse registry.yaml"; rm -f "$parsed"; return 1; }

  source "$parsed"
  rm -f "$parsed"

  for skill in "${CUSTOM_INSTALL[@]}" "${GLOBAL_SKILLS[@]}"; do
    download_skill "$skills_dir" "$skill"
  done

  info "  Installing agents..."
  for agent in "${GLOBAL_AGENTS[@]}"; do
    download_agent "$agents_dir" "$agent"
  done
}

# --- Orchestration ---

info "Spellbook Bootstrap"
if [ -n "$SPELLBOOK" ]; then
  info "Local checkout detected: $SPELLBOOK"
  info "Mode: symlink"
else
  info "No local checkout found."
  info "Mode: download from GitHub"
fi
echo

installed=0

for harness in claude codex pi; do
  harness_dir="$HOME/.$harness"

  # Detect harness
  if [ ! -d "$harness_dir" ] && ! command -v "$harness" &>/dev/null; then
    continue
  fi

  info "Detected: $harness"
  mkdir -p "$harness_dir"

  if [ -n "$SPELLBOOK" ]; then
    link_local "$harness" "$harness_dir"
  else
    local agents_dir="$harness_dir/agents"
    install_remote "$harness_dir/skills" "$agents_dir"
  fi

  installed=$((installed + 1))
  echo
done

if [ "$installed" -eq 0 ]; then
  warn "No agent harnesses detected."
  warn "Installing to ~/.claude/ as default."
  mkdir -p "$HOME/.claude"
  if [ -n "$SPELLBOOK" ]; then
    link_local "claude" "$HOME/.claude"
  else
    install_remote "$HOME/.claude/skills" "$HOME/.claude/agents"
  fi
  installed=1
fi

ok "Done. Installed to $installed harness(es)."
echo
if [ -n "$SPELLBOOK" ]; then
  info "Mode: symlink (edits in $SPELLBOOK propagate instantly)"
else
  info "Mode: downloaded from GitHub"
  info "For symlink mode, clone spellbook and re-run."
fi
