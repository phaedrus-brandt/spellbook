#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  echo "Usage: sync.sh <harness> [--dry-run]"
  echo "Harnesses: claude | codex | factory | gemini | pi | all"
  exit 1
}

[[ $# -lt 1 ]] && usage

HARNESS="$1"
DRY_RUN="${2:-}"

log() { echo "[sync] $*"; }
dry() { [[ "$DRY_RUN" == "--dry-run" ]]; }

# Symlink a single skill dir from repo into target dir.
# Backs up existing non-symlink dirs to .bak/
link_skill() {
  local skill_name="$1" target_dir="$2"
  local src="$REPO_DIR/$skill_name"
  local dst="$target_dir/$skill_name"

  [[ ! -d "$src" ]] && return

  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink "$dst")"
    if [[ "$current" == "$src" ]]; then
      return  # already correct
    fi
    # Remove stale symlink
    if dry; then
      log "[dry] rm symlink $dst -> $current"
    else
      rm "$dst"
    fi
  elif [[ -d "$dst" ]]; then
    # Back up existing real directory
    local backup_dir="$target_dir/.bak"
    if dry; then
      log "[dry] backup $dst -> $backup_dir/$skill_name"
    else
      mkdir -p "$backup_dir"
      mv "$dst" "$backup_dir/$skill_name"
    fi
  fi

  if dry; then
    log "[dry] ln -s $src -> $dst"
  else
    ln -s "$src" "$dst"
  fi
}

# Sync all skills from repo into a target directory.
# $1 = target dir, $2... = skip patterns (optional)
sync_harness() {
  local target_dir="$1"
  shift
  local -a skip_patterns=("$@")

  [[ ! -d "$target_dir" ]] && { log "SKIP: $target_dir does not exist"; return; }

  local count=0
  for skill_dir in "$REPO_DIR"/*/; do
    local skill_name
    skill_name="$(basename "$skill_dir")"

    # Skip non-skill dirs
    [[ "$skill_name" == "scripts" ]] && continue
    [[ "$skill_name" == ".git" ]] && continue
    [[ "$skill_name" == ".bak" ]] && continue

    # Skip protected patterns
    local skip=false
    for pat in "${skip_patterns[@]+"${skip_patterns[@]}"}"; do
      [[ "$skill_name" == "$pat" ]] && skip=true
    done
    $skip && continue

    link_skill "$skill_name" "$target_dir"
    ((count++))
  done

  log "$target_dir: $count skills synced"
}

# Sync specific skills only (for Pi shared skills)
sync_specific() {
  local target_dir="$1"
  shift
  local -a skills=("$@")

  [[ ! -d "$target_dir" ]] && { log "SKIP: $target_dir does not exist"; return; }

  for skill_name in "${skills[@]}"; do
    link_skill "$skill_name" "$target_dir"
  done

  log "$target_dir: ${#skills[@]} shared skills synced"
}

do_claude() {
  log "=== Claude ==="
  sync_harness "$HOME/.claude/skills"
}

do_codex() {
  log "=== Codex ==="
  sync_harness "$HOME/.codex/skills" ".system"
}

do_factory() {
  log "=== Factory ==="
  sync_harness "$HOME/.factory/skills"
}

do_gemini() {
  log "=== Gemini ==="
  sync_harness "$HOME/.gemini/skills"

  # Also handle antigravity/global_skills symlinks
  local ag_dir="$HOME/.gemini/antigravity/global_skills"
  if [[ -d "$ag_dir" ]]; then
    for link in "$ag_dir"/*; do
      [[ ! -L "$link" ]] && continue
      local name
      name="$(basename "$link")"
      [[ -d "$REPO_DIR/$name" ]] && link_skill "$name" "$ag_dir"
    done
    log "$ag_dir: antigravity symlinks repointed"
  fi
}

do_pi() {
  log "=== Pi ==="
  # Pi is managed by pi-agent-config. Only repoint shared symlinks.
  local pi_skills="$HOME/Development/pi-agent-config/skills"
  local -a shared_skills=(
    agent-browser dogfood skill-creator taste-skill
    vercel-composition-patterns vercel-react-best-practices
    web-design-guidelines
  )
  sync_specific "$pi_skills" "${shared_skills[@]}"
}

case "$HARNESS" in
  claude)  do_claude ;;
  codex)   do_codex ;;
  factory) do_factory ;;
  gemini)  do_gemini ;;
  pi)      do_pi ;;
  all)     do_claude; do_codex; do_factory; do_gemini; do_pi ;;
  *)       usage ;;
esac

log "Done."
