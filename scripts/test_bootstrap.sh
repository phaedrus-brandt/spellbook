#!/usr/bin/env bash
# Regression tests for bootstrap.sh Codex installation behavior.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

setup() {
  ORIG_DIR="$(pwd)"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/.codex/skills/.system"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_HOME"
}

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

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  local actual
  if "$@" >/dev/null 2>&1; then actual=0; else actual=$?; fi
  assert_eq "$desc" "$expected" "$actual"
}

symlink_target_or_missing() {
  local path="$1"
  if [ -L "$path" ]; then
    readlink "$path"
  else
    printf '__missing__\n'
  fi
}

run_bootstrap() {
  (
    cd "$REPO_ROOT"
    export SPELLBOOK_DIR="$REPO_ROOT"
    bash ./bootstrap.sh
  )
}

test_codex_bootstrap_installs_skills_with_hidden_system_dir() {
  assert_exit "bootstrap succeeds for codex per-entry skills install" 0 run_bootstrap

  local target
  target="$(symlink_target_or_missing "$HOME/.codex/skills/shape")"
  assert_eq "bootstrap links a codex skill" \
    "$REPO_ROOT/skills/shape" "$target"
}

test_codex_bootstrap_links_top_level_config() {
  assert_exit "bootstrap succeeds and links top-level codex config" 0 run_bootstrap

  local target
  target="$(symlink_target_or_missing "$HOME/.codex/config.toml")"
  assert_eq "bootstrap links ~/.codex/config.toml" \
    "$REPO_ROOT/harnesses/codex/config.toml" "$target"
}

test_codex_bootstrap_preserves_existing_top_level_config() {
  cat > "$HOME/.codex/config.toml" <<'EOF'
model = "custom"
EOF

  assert_exit "bootstrap preserves existing codex config.toml" 0 run_bootstrap

  local content
  content="$(cat "$HOME/.codex/config.toml")"
  assert_eq "bootstrap leaves existing ~/.codex/config.toml untouched" \
    'model = "custom"' "$content"
}

run_tests() {
  local funcs
  funcs="$(declare -F | awk '/test_codex_bootstrap_/{print $3}')"
  for t in $funcs; do
    setup
    "$t"
    teardown
  done

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}

run_tests
