#!/usr/bin/env bash
# Verify first-party spellbook skills include Codex UI metadata.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  $desc (expected '$expected', got '$actual')"
  fi
}

check_skill_metadata() {
  local skill_dir="$1"
  local skill_name
  skill_name="$(basename "$skill_dir")"
  local metadata="$skill_dir/agents/openai.yaml"

  if [ ! -f "$metadata" ]; then
    FAIL=$((FAIL + 1))
    echo "  FAIL  $skill_name has agents/openai.yaml"
    return
  fi
  PASS=$((PASS + 1))
  echo "  PASS  $skill_name has agents/openai.yaml"

  local display_count short_count
  display_count="$(grep -c '^  display_name: ' "$metadata" || true)"
  short_count="$(grep -c '^  short_description: ' "$metadata" || true)"
  assert_eq "$skill_name defines display_name" "1" "$display_count"
  assert_eq "$skill_name defines short_description" "1" "$short_count"
}

run_tests() {
  local skill_dir
  for skill_dir in "$REPO_ROOT"/skills/*; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue
    check_skill_metadata "$skill_dir"
  done

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}

run_tests
