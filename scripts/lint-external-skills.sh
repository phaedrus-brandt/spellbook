#!/usr/bin/env bash
# Lint installed external skills in skills/.external/ for self-containment
# violations — hardcoded absolute paths or tree escapes that break when a
# skill is symlinked into a foreign project.
#
# A self-contained skill resolves its own scripts via $SCRIPT_DIR (readlink)
# and sources helpers from within its own directory. Violations:
#   - Hardcoded /Users/, /home/, ~/.claude, ~/.agents, ~/.codex, $HOME/.claude
#   - ../../ escapes in scripts (shell/python) that reach outside the skill tree
#
# Default: report violations, exit 0 (advisory).
# --strict: exit non-zero if any violations found (for CI gates).
#
# Usage:
#   ./scripts/lint-external-skills.sh             # report
#   ./scripts/lint-external-skills.sh --strict    # gate

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXTERNAL_ROOT="$REPO_ROOT/skills/.external"

STRICT=0
case "${1:-}" in
  --strict) STRICT=1 ;;
  -h|--help) sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ -d "$EXTERNAL_ROOT" ] || { echo "no .external/ — run sync-external.sh first"; exit 0; }

total=0
dirty=0
declare -a DIRTY_ALIASES=()

for alias_dir in "$EXTERNAL_ROOT"/*/; do
  [ -d "$alias_dir" ] || continue
  alias="$(basename "$alias_dir")"
  [ "$alias" = "_checkouts" ] && continue
  total=$((total + 1))

  # Patterns to flag. Scoped to file contents, not filenames.
  # Exclude the skill's own .sync-meta.json (our provenance file, not upstream).
  violations="$(
    grep -rnI \
      --exclude='.sync-meta.json' \
      -e '/Users/' \
      -e '/home/[a-z]' \
      -e '\$HOME/\.claude' \
      -e '\$HOME/\.agents' \
      -e '\$HOME/\.codex' \
      -e '~/\.claude' \
      -e '~/\.agents' \
      -e '~/\.codex' \
      "$alias_dir" 2>/dev/null || true
  )"

  # Separately flag ../../../ or deeper escapes in script files.
  escapes="$(
    grep -rnI \
      --include='*.sh' --include='*.py' --include='*.ts' --include='*.js' \
      -E '\.\./\.\./\.\./' \
      "$alias_dir" 2>/dev/null || true
  )"

  combined="${violations}${escapes:+$'\n'$escapes}"
  if [ -n "$combined" ]; then
    dirty=$((dirty + 1))
    DIRTY_ALIASES+=("$alias")
    count="$(printf '%s\n' "$combined" | grep -c . || true)"
    printf '\033[0;33m%s\033[0m — %d violation(s)\n' "$alias" "$count"
    # Show first 3 examples per alias.
    printf '%s\n' "$combined" | head -3 | sed 's|^'"$EXTERNAL_ROOT"'/|  |'
    [ "$count" -gt 3 ] && printf '  ... +%d more\n' $((count - 3))
    printf '\n'
  fi
done

clean=$((total - dirty))
printf '\033[0;32m%d / %d aliases self-contained\033[0m\n' "$clean" "$total"
if [ "$dirty" -gt 0 ]; then
  printf '\033[0;33m%d alias(es) with self-containment violations:\033[0m %s\n' \
    "$dirty" "${DIRTY_ALIASES[*]}"
  printf 'These skills hardcode user-specific paths and will break when symlinked\n'
  printf 'into a foreign project. See registry.yaml notes per source.\n'
fi

if [ "$STRICT" = "1" ] && [ "$dirty" -gt 0 ]; then
  exit 1
fi
exit 0
