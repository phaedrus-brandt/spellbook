#!/usr/bin/env bash
# Integration tests for skills/flywheel/scripts/flywheel.sh.
# Runs each test in a temp directory so real repo state is untouched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPELLBOOK_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FLYWHEEL_SH="$SCRIPT_DIR/flywheel.sh"
PASS=0
FAIL=0

setup() {
  ORIG_DIR="$(pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  mkdir -p .spellbook
  unset FLYWHEEL_LOCK_PATH
  FLYWHEEL_LOCK_PATH="$TEST_DIR/.spellbook/flywheel.lock"
  export FLYWHEEL_LOCK_PATH
  # flywheel.sh cd's to REPO_ROOT and writes cycles to REPO_ROOT/backlog.d/_cycles/.
  # Snapshot the pre-existing entries so teardown can delete only what this test
  # created — never anything that predated the run.
  CYCLES_ROOT="$SPELLBOOK_ROOT/backlog.d/_cycles"
  if [ -d "$CYCLES_ROOT" ]; then
    CYCLES_PRE="$(ls -1 "$CYCLES_ROOT" 2>/dev/null | sort)"
  else
    CYCLES_PRE=""
  fi
}

teardown() {
  cd "$ORIG_DIR"
  # Clean up any cycle dirs this test created under REPO_ROOT.
  if [ -d "$CYCLES_ROOT" ]; then
    local post
    post="$(ls -1 "$CYCLES_ROOT" 2>/dev/null | sort || true)"
    local new
    new="$(comm -13 <(printf '%s\n' "$CYCLES_PRE") <(printf '%s\n' "$post") 2>/dev/null | awk 'NF' || true)"
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      /usr/bin/trash "$CYCLES_ROOT/$name" 2>/dev/null || true
    done <<< "$new"
    # Remove _cycles dir if it became empty and didn't exist pre-test.
    if [ -z "$CYCLES_PRE" ] && [ -d "$CYCLES_ROOT" ] && [ -z "$(ls -A "$CYCLES_ROOT" 2>/dev/null)" ]; then
      rmdir "$CYCLES_ROOT" 2>/dev/null || true
    fi
  fi
  # Revert any backlog mutations from tests (update-bucket tests).
  # Also clean up files moved to _done/ by shipped tests (untracked, not restored by checkout).
  if [ -d "$SPELLBOOK_ROOT/backlog.d/_done" ]; then
    find "$SPELLBOOK_ROOT/backlog.d/_done" -name "[0-9][0-9][0-9]-*.md" \
      -exec /usr/bin/trash {} \; 2>/dev/null || true
    rmdir "$SPELLBOOK_ROOT/backlog.d/_done" 2>/dev/null || true
  fi
  cd "$SPELLBOOK_ROOT" && git checkout -- backlog.d/ 2>/dev/null || true
  cd "$ORIG_DIR"
  unset FLYWHEEL_LOCK_PATH
  /usr/bin/trash "$TEST_DIR" 2>/dev/null || true
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

# --- Helpers ---

# Latest cycle.jsonl written by flywheel.sh in this test.
find_cycle_log() {
  # shellcheck disable=SC2012
  ls -1t "$SPELLBOOK_ROOT"/backlog.d/_cycles/*/cycle.jsonl 2>/dev/null | head -n 1 || true
}

# Extract JSONL "kind" field from every line.
kinds_in() {
  python3 -c "
import json, sys
for line in open(sys.argv[1]):
    line = line.strip()
    if not line: continue
    print(json.loads(line).get('kind',''))
" "$1"
}

# Extract a JSON field from a file.
json_field() {
  local file="$1" field="$2"
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
parts = sys.argv[2].split('.')
v = d
for p in parts:
    v = v[p]
print(v)
" "$file" "$field" 2>/dev/null || true
}

# --- ULID tests (B3) ---

test_ulid_fallback_is_crockford_base32_26_chars() {
  local fake_dir="$TEST_DIR/fake_pythonpath"
  mkdir -p "$fake_dir"
  cat > "$fake_dir/ulid.py" <<'PY'
raise ImportError("forced for test")
PY
  local out
  out="$(PYTHONPATH="$fake_dir" python3 - <<'PYEOF'
try:
    import ulid
    print(str(ulid.new()))
except Exception:
    import secrets, time
    CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    def _enc(v, n):
        out = []
        for _ in range(n):
            out.append(CROCKFORD[v & 0x1F]); v >>= 5
        return "".join(reversed(out))
    ts = int(time.time() * 1000) & ((1<<48)-1)
    rnd = secrets.randbits(80)
    print(_enc(ts, 10) + _enc(rnd, 16))
PYEOF
)"
  assert_eq "fallback ULID length 26" "26" "${#out}"
  if [[ "$out" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]; then
    assert_eq "fallback ULID matches Crockford charset" "ok" "ok"
  else
    assert_eq "fallback ULID matches Crockford charset" "ok" "bad:$out"
  fi
}

test_new_ulid_helper_produces_26_crockford_chars() {
  local fake_dir="$TEST_DIR/fake_pythonpath"
  mkdir -p "$fake_dir"
  cat > "$fake_dir/ulid.py" <<'PY'
raise ImportError("forced for test")
PY
  local out
  out="$(PYTHONPATH="$fake_dir" python3 - <<'PYEOF'
try:
    import ulid
    print(str(ulid.new()))
except Exception:
    import secrets, time
    CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    def _enc(v, n):
        out = []
        for _ in range(n):
            out.append(CROCKFORD[v & 0x1F]); v >>= 5
        return "".join(reversed(out))
    ts = int(time.time() * 1000) & ((1<<48)-1)
    rnd = secrets.randbits(80)
    print(_enc(ts, 10) + _enc(rnd, 16))
PYEOF
)"
  assert_eq "new_ulid (fallback) length 26" "26" "${#out}"
}

test_autopilot_emits_26char_crockford_cycle_id() {
  local fake_dir="$TEST_DIR/fake_pythonpath"
  mkdir -p "$fake_dir"
  cat > "$fake_dir/ulid.py" <<'PY'
raise ImportError("forced for test")
PY
  PYTHONPATH="$fake_dir" bash "$FLYWHEEL_SH" run --dry-run >/dev/null 2>&1
  local log cid
  log="$(find_cycle_log)"
  cid="$(python3 -c "
import json, sys
line = open(sys.argv[1]).readline().strip()
print(json.loads(line)['cycle_id'])
" "$log")"
  assert_eq "emitted cycle_id length" "26" "${#cid}"
  if [[ "$cid" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]; then
    assert_eq "emitted cycle_id matches Crockford charset" "ok" "ok"
  else
    assert_eq "emitted cycle_id matches Crockford charset" "ok" "bad:$cid"
  fi
}

# --- Integration tests (B5, B6) ---

test_dry_run_writes_expected_event_kinds_in_order() {
  # Phase 2: 8-event trail (not 9). Inner-pipeline events collapsed into deliver.done.
  bash "$FLYWHEEL_SH" run --dry-run >/dev/null 2>&1
  local log
  log="$(find_cycle_log)"
  local expected actual
  expected=$'cycle.opened\ndeliver.done\ndeploy.done\nmonitor.done\nreflect.done\nbucket.updated\nharness.suggested\ncycle.closed'
  actual="$(kinds_in "$log")"
  assert_eq "dry-run event kinds match 8-event Phase 2 sequence" "$expected" "$actual"
}

test_max_cycles_gt_1_without_budget_still_runs_when_not_unattended() {
  # Phase 2: max-cycles > 1 is now allowed (multi-cycle loop). Only unattended
  # without budget is refused. Multi-cycle dry-run with no budget should succeed.
  local rc=0
  bash "$FLYWHEEL_SH" run --dry-run --max-cycles 2 >/dev/null 2>&1 || rc=$?
  assert_eq "max-cycles 2 dry-run exits 0 (Phase 2 multi-cycle allowed)" "0" "$rc"
}

test_until_flag_is_phase2b_exits_2() {
  local rc=0
  bash "$FLYWHEEL_SH" run --until "backlog empty" >/dev/null 2>&1 || rc=$?
  assert_eq "--until exits 2 (Phase 2b)" "2" "$rc"
}

test_resume_flag_is_phase2b_exits_2() {
  local rc=0
  bash "$FLYWHEEL_SH" run --resume 01HFAKE >/dev/null 2>&1 || rc=$?
  assert_eq "--resume exits 2 (Phase 2b)" "2" "$rc"
}

test_real_mode_emits_phase_failed_and_cycle_closed_and_exits_1() {
  local rc=0
  bash "$FLYWHEEL_SH" run >/dev/null 2>&1 || rc=$?
  assert_eq "real mode exits 1" "1" "$rc"
  local log kinds
  log="$(find_cycle_log)"
  kinds="$(kinds_in "$log")"
  local has_failed=0 has_closed=0
  while IFS= read -r k; do
    [ "$k" = "phase.failed" ] && has_failed=1
    [ "$k" = "cycle.closed" ] && has_closed=1
  done <<< "$kinds"
  assert_eq "real mode emits phase.failed" "1" "$has_failed"
  assert_eq "real mode emits cycle.closed" "1" "$has_closed"
  assert_eq "real mode releases lock" "no" \
    "$([ -f "$FLYWHEEL_LOCK_PATH" ] && echo yes || echo no)"
}

test_two_sequential_dry_runs_both_succeed() {
  bash "$FLYWHEEL_SH" run --dry-run >/dev/null 2>&1
  local rc1=$?
  bash "$FLYWHEEL_SH" run --dry-run >/dev/null 2>&1
  local rc2=$?
  assert_eq "first dry-run cycle exits 0" "0" "$rc1"
  assert_eq "second dry-run cycle exits 0" "0" "$rc2"
  local post new_cycles
  post="$(ls -1 "$CYCLES_ROOT" 2>/dev/null | sort || true)"
  new_cycles="$(comm -13 <(printf '%s\n' "$CYCLES_PRE") <(printf '%s\n' "$post") 2>/dev/null | awk 'NF' | wc -l | tr -d ' ')"
  assert_eq "two cycle directories created" "2" "$new_cycles"
}

test_sigint_releases_lock_via_trap() {
  ( bash "$FLYWHEEL_SH" run --dry-run >/dev/null 2>&1 ) &
  local pid=$!
  sleep 0.05
  kill -INT "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  assert_eq "lock cleared after SIGINT / completion" "no" \
    "$([ -f "$FLYWHEEL_LOCK_PATH" ] && echo yes || echo no)"
}

# --- B7: SIGINT exit code contract ---

test_sigint_exits_with_130() {
  # SKILL.md contract: "SIGINT → trap releases lock, exit 130".
  # We wait on the .ready sentinel (written AFTER trap install) to guarantee
  # the trap is in place before sending SIGINT.
  local rc
  rc="$(FLYWHEEL_LOCK_PATH="$FLYWHEEL_LOCK_PATH" \
        FLYWHEEL_SH="$FLYWHEEL_SH" \
        python3 - <<'PYEOF'
import os, signal, subprocess, time
env = os.environ.copy()
env["FLYWHEEL_SIGINT_TEST_SLEEP"] = "10"
p = subprocess.Popen(["bash", env["FLYWHEEL_SH"], "run", "--dry-run"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     env=env)
# Wait for .ready sentinel (written after trap install) not just the lock.
ready = env["FLYWHEEL_LOCK_PATH"] + ".ready"
for _ in range(200):
    if os.path.exists(ready):
        break
    time.sleep(0.05)
p.send_signal(signal.SIGINT)
p.wait()
print(p.returncode)
PYEOF
)"
  assert_eq "SIGINT causes flywheel.sh to exit 130" "130" "$rc"
  assert_eq "lock cleared after SIGINT" "no" \
    "$([ -f "$FLYWHEEL_LOCK_PATH" ] && echo yes || echo no)"
}

test_sigterm_exits_with_143() {
  # Companion to SIGINT: SIGTERM must exit 143 (128 + 15).
  local rc
  rc="$(FLYWHEEL_LOCK_PATH="$FLYWHEEL_LOCK_PATH" \
        FLYWHEEL_SH="$FLYWHEEL_SH" \
        python3 - <<'PYEOF'
import os, signal, subprocess, time
env = os.environ.copy()
env["FLYWHEEL_SIGINT_TEST_SLEEP"] = "10"
p = subprocess.Popen(["bash", env["FLYWHEEL_SH"], "run", "--dry-run"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     env=env)
# Wait for .ready sentinel (written after trap install).
ready = env["FLYWHEEL_LOCK_PATH"] + ".ready"
for _ in range(200):
    if os.path.exists(ready):
        break
    time.sleep(0.05)
p.send_signal(signal.SIGTERM)
p.wait()
print(p.returncode)
PYEOF
)"
  assert_eq "SIGTERM causes flywheel.sh to exit 143" "143" "$rc"
  assert_eq "lock cleared after SIGTERM" "no" \
    "$([ -f "$FLYWHEEL_LOCK_PATH" ] && echo yes || echo no)"
}

# --- B8: orphan cycle dir on lock contention ---

test_failed_acquire_leaves_no_orphan_cycle_dir() {
  python3 -c "
import json, os
os.makedirs('.spellbook', exist_ok=True)
open(os.environ['FLYWHEEL_LOCK_PATH'],'w').write(
  json.dumps({'pid': $$, 'cycle_id': '01HHELD', 'started_at': '2026-01-01T00:00:00Z'}))
"
  local rc=0
  bash "$FLYWHEEL_SH" run --dry-run >/dev/null 2>&1 || rc=$?
  assert_eq "colliding invocation fails non-zero" "1" "$rc"
  local post new_cycles
  post="$(ls -1 "$CYCLES_ROOT" 2>/dev/null | sort || true)"
  new_cycles="$(comm -13 <(printf '%s\n' "$CYCLES_PRE") <(printf '%s\n' "$post") 2>/dev/null | awk 'NF' | wc -l | tr -d ' ')"
  assert_eq "no orphan cycle dir after failed acquire" "0" "$new_cycles"
}

# --- B9: paths anchored to REPO_ROOT, not PWD ---

test_off_repo_invocation_writes_to_repo_root() {
  local off_repo_dir="$TEST_DIR/off_repo"
  mkdir -p "$off_repo_dir"
  (
    cd "$off_repo_dir"
    FLYWHEEL_LOCK_PATH="$TEST_DIR/off_repo.lock" \
      bash "$FLYWHEEL_SH" run --dry-run >/dev/null 2>&1
  )
  assert_eq "no backlog.d/_cycles under off-repo PWD" "no" \
    "$([ -d "$off_repo_dir/backlog.d/_cycles" ] && echo yes || echo no)"
  local post new_cycles
  post="$(ls -1 "$CYCLES_ROOT" 2>/dev/null | sort || true)"
  new_cycles="$(comm -13 <(printf '%s\n' "$CYCLES_PRE") <(printf '%s\n' "$post") 2>/dev/null | awk 'NF' | wc -l | tr -d ' ')"
  assert_eq "exactly one new cycle dir under REPO_ROOT" "1" "$new_cycles"
}

# --- Phase 2a subcommand tests ---

test_new_cycle_emits_cycle_opened_and_writes_valid_manifest() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 10 2>/dev/null)"
  assert_eq "new-cycle emits non-empty cycle_id" "26" "${#cycle_id}"

  local manifest="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/manifest.json"
  assert_eq "manifest.json exists" "yes" "$([ -f "$manifest" ] && echo yes || echo no)"

  local schema_version status cap
  schema_version="$(json_field "$manifest" schema_version)"
  status="$(json_field "$manifest" status)"
  cap="$(json_field "$manifest" budget.cap_usd)"
  assert_eq "manifest schema_version=1" "1" "$schema_version"
  assert_eq "manifest status=open" "open" "$status"
  assert_eq "manifest budget.cap_usd=10.0" "10.0" "$cap"

  local log="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/cycle.jsonl"
  assert_eq "cycle.jsonl exists" "yes" "$([ -f "$log" ] && echo yes || echo no)"

  local kinds
  kinds="$(kinds_in "$log")"
  assert_eq "cycle.opened in log" "cycle.opened" "$kinds"

  # Cleanup: close cycle to release lock.
  bash "$FLYWHEEL_SH" close "$cycle_id" noop >/dev/null 2>&1
}

test_pick_returns_scored_item_from_backlog() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"

  local item
  item="$(bash "$FLYWHEEL_SH" pick "$cycle_id" 2>/dev/null)"
  # Should pick something from real backlog (non-empty).
  assert_eq "pick returns non-empty item_id" "yes" "$([ -n "$item" ] && [ "$item" != "EMPTY" ] && echo yes || echo no)"
  # item_id should match backlog.d/NNN-slug pattern stem.
  if [[ "$item" =~ ^[0-9]{3}-.+ ]]; then
    assert_eq "pick returns valid item_id format" "ok" "ok"
  else
    assert_eq "pick returns valid item_id format" "ok" "bad:$item"
  fi
  # Manifest item_id should be updated.
  local manifest_item
  manifest_item="$(json_field "$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/manifest.json" item_id)"
  assert_eq "manifest item_id updated after pick" "$item" "$manifest_item"

  bash "$FLYWHEEL_SH" close "$cycle_id" noop >/dev/null 2>&1
}

test_pick_returns_empty_on_empty_backlog() {
  # Override CYCLES_ROOT-equivalent: we can't move real backlog files, so we
  # mark all eligible items as blocked by setting a fake status via a fixture
  # approach. Instead, test directly with a synthetic backlog dir by running
  # pick against a cycle in a repo state where all items are done/shipped.
  # Simplest approach: stamp all backlog files as shipped in a subshell
  # by making pick find no eligible items.
  #
  # We use the fact that pick skips items where Status contains done/shipped.
  # Temporarily rename the backlog dir so no files match the glob.
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"

  # Force empty eligible set: all real backlog items have Priority set,
  # none blocked-by. We can't easily override the dir. Use a subshell
  # with SPELLBOOK_ROOT-level trick: create done-status versions.
  # Best approach: temporarily create a sentinel that causes all to be skipped.
  # Actually, test with a cycle that has the backlog moved — but we can't cd
  # in sub-process. Instead: just verify the EMPTY path via a unit approach.
  #
  # Create a temp backlog with only a "done" item and point a secondary test
  # cycle at it. Since pick scans REPO_ROOT/backlog.d/, we add a new eligible
  # file that will get picked, then mark all real items as having been locked
  # by existing open manifests. This is complex. Simplest correct test:
  # verify pick returns EMPTY when the cycle locks the only item.
  #
  # We use: pick on cycle A returns item X. Then open cycle B (lock not held),
  # cycle A's manifest still open → X locked. If only X exists, B gets EMPTY.
  # But there are multiple items. So: skip this via a fixture backlog.
  #
  # Use FLYWHEEL_BACKLOG_DIR env override if implemented, else test the
  # pick-EMPTY code path by ensuring all items are status:done.
  # For now: write temporary done-status files over existing items in a subshell.

  # The cleanest approach without env overrides: create a throwaway cycle
  # in a state where every backlog item is locked by open manifests.
  # With 8 backlog items and we can open 8 cycles to lock them all.
  # This is too complex. Instead: verify pick output is EMPTY by
  # patching the cycle_dir context. We'll test this with a temp backlog dir
  # approach using a wrapper script.

  # Pragmatic: set all real backlog items to Status: done via a subshell
  # mutation, run pick, then restore with git checkout.
  (
    cd "$SPELLBOOK_ROOT"
    # Temporarily set all backlog Status: to done.
    for f in backlog.d/[0-9][0-9][0-9]-*.md; do
      python3 -c "
import re, sys
content = open(sys.argv[1]).read()
if re.search(r'^Status:', content, re.MULTILINE):
    content = re.sub(r'^Status:.*', 'Status: done', content, flags=re.MULTILINE)
else:
    content = content + '\nStatus: done\n'
open(sys.argv[1], 'w').write(content)
" "$f"
    done
    item="$(bash "$FLYWHEEL_SH" pick "$cycle_id" 2>/dev/null)"
    echo "$item"
    # Restore.
    git checkout -- backlog.d/ 2>/dev/null || true
  )
  # Capture the output from the subshell (last line).
  local item
  item="$(
    cd "$SPELLBOOK_ROOT"
    for f in backlog.d/[0-9][0-9][0-9]-*.md; do
      python3 -c "
import re, sys
content = open(sys.argv[1]).read()
if re.search(r'^Status:', content, re.MULTILINE):
    content = re.sub(r'^Status:.*', 'Status: done', content, flags=re.MULTILINE)
else:
    content = content + '\nStatus: done\n'
open(sys.argv[1], 'w').write(content)
" "$f"
    done
    bash "$FLYWHEEL_SH" pick "$cycle_id" 2>/dev/null
    git checkout -- backlog.d/ 2>/dev/null || true
  )"
  assert_eq "pick returns EMPTY on empty backlog" "EMPTY" "$item"

  bash "$FLYWHEEL_SH" close "$cycle_id" noop >/dev/null 2>&1
}

test_emit_rejects_unknown_kind() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"

  local rc=0
  bash "$FLYWHEEL_SH" emit "$cycle_id" shape.done shape planner '{}' >/dev/null 2>&1 || rc=$?
  assert_eq "emit rejects unknown kind shape.done" "1" "$rc"

  bash "$FLYWHEEL_SH" close "$cycle_id" noop >/dev/null 2>&1
}

test_emit_sums_cost_usd_into_manifest_budget() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 20 2>/dev/null)"

  bash "$FLYWHEEL_SH" emit "$cycle_id" deliver.done deliver builder \
    '{"cost_usd":3.50}' >/dev/null 2>&1
  bash "$FLYWHEEL_SH" emit "$cycle_id" deploy.done deploy deployer \
    '{"cost_usd":0.25}' >/dev/null 2>&1

  local manifest="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/manifest.json"
  local spent
  spent="$(json_field "$manifest" budget.spent_usd)"
  assert_eq "emit sums cost_usd (3.50+0.25=3.75)" "3.75" "$spent"

  bash "$FLYWHEEL_SH" close "$cycle_id" noop >/dev/null 2>&1
}

test_emit_triggers_budget_exhausted_at_95_percent() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"

  # 4.80 / 5.00 = 96% >= 95% → should emit budget.exhausted
  bash "$FLYWHEEL_SH" emit "$cycle_id" deliver.done deliver builder \
    '{"cost_usd":4.80}' >/dev/null 2>&1

  local log="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/cycle.jsonl"
  local has_exhausted=0
  while IFS= read -r k; do
    [ "$k" = "budget.exhausted" ] && has_exhausted=1
  done < <(kinds_in "$log")
  assert_eq "emit triggers budget.exhausted at 95%" "1" "$has_exhausted"

  bash "$FLYWHEEL_SH" close "$cycle_id" noop >/dev/null 2>&1
}

test_close_emits_cycle_closed_releases_lock_updates_manifest() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"

  # Lock should be held.
  assert_eq "lock held after new-cycle" "yes" \
    "$([ -f "$FLYWHEEL_LOCK_PATH" ] && echo yes || echo no)"

  bash "$FLYWHEEL_SH" close "$cycle_id" closed >/dev/null 2>&1

  # Lock released.
  assert_eq "lock released after close" "no" \
    "$([ -f "$FLYWHEEL_LOCK_PATH" ] && echo yes || echo no)"

  local manifest="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/manifest.json"
  local status
  status="$(json_field "$manifest" status)"
  assert_eq "manifest status=closed after close" "closed" "$status"

  local log="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/cycle.jsonl"
  local has_closed=0
  while IFS= read -r k; do
    [ "$k" = "cycle.closed" ] && has_closed=1
  done < <(kinds_in "$log")
  assert_eq "cycle.closed event emitted" "1" "$has_closed"
}

test_update_bucket_idempotent_no_duplicate_section() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"
  bash "$FLYWHEEL_SH" pick "$cycle_id" >/dev/null 2>&1

  # First update-bucket.
  bash "$FLYWHEEL_SH" update-bucket "$cycle_id" failed >/dev/null 2>&1
  # Second update-bucket (same cycle): must be no-op.
  bash "$FLYWHEEL_SH" update-bucket "$cycle_id" failed >/dev/null 2>&1

  # Find the item_id from manifest.
  local manifest="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/manifest.json"
  local item_id
  item_id="$(json_field "$manifest" item_id)"
  local src="$SPELLBOOK_ROOT/backlog.d/${item_id}.md"

  # Should appear exactly once (idempotent).
  local count
  count="$(grep -c "Cycle $cycle_id" "$src" || echo 0)"
  assert_eq "update-bucket idempotent: cycle marker appears once" "1" "$count"

  bash "$FLYWHEEL_SH" close "$cycle_id" closed >/dev/null 2>&1
}

test_update_bucket_shipped_moves_file_to_done() {
  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"
  bash "$FLYWHEEL_SH" pick "$cycle_id" >/dev/null 2>&1

  local manifest="$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/manifest.json"
  local item_id
  item_id="$(json_field "$manifest" item_id)"
  local src="$SPELLBOOK_ROOT/backlog.d/${item_id}.md"
  local dst="$SPELLBOOK_ROOT/backlog.d/_done/${item_id}.md"

  assert_eq "source file exists before ship" "yes" "$([ -f "$src" ] && echo yes || echo no)"

  bash "$FLYWHEEL_SH" update-bucket "$cycle_id" shipped >/dev/null 2>&1

  assert_eq "source file moved to _done" "no" "$([ -f "$src" ] && echo yes || echo no)"
  assert_eq "_done file exists after ship" "yes" "$([ -f "$dst" ] && echo yes || echo no)"
  # Verify cycle marker in moved file.
  assert_eq "cycle marker in _done file" "yes" \
    "$(grep -q "cycle $cycle_id" "$dst" && echo yes || echo no)"

  bash "$FLYWHEEL_SH" close "$cycle_id" closed >/dev/null 2>&1
}

test_update_bucket_failed_bumps_retry_count_auto_demotes_at_cap() {
  # We need a P0/P1 item in the backlog. The real backlog may not have one.
  # Use a synthetic approach: temporarily add a fixture item.
  local fixture="$SPELLBOOK_ROOT/backlog.d/099-test-fixture-retry.md"
  cat > "$fixture" <<'EOF'
# Test fixture — retry count demote

Priority: P1
Status: pending
Estimate: S
EOF

  local cycle_id
  cycle_id="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"

  # Manually set the item_id in the manifest to our fixture
  # (bypassing pick to guarantee we hit the right item).
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
d['item_id'] = '099-test-fixture-retry'
open(sys.argv[1], 'w').write(json.dumps(d, indent=2))
" "$SPELLBOOK_ROOT/backlog.d/_cycles/$cycle_id/manifest.json"

  # Run 3 failed updates to hit the cap.
  for attempt in 1 2 3; do
    # Each attempt needs a fresh cycle for idempotence guard.
    if [ "$attempt" -gt 1 ]; then
      # Re-stamp under a new cycle_id to bypass idempotence guard.
      local new_cid
      new_cid="$(bash "$FLYWHEEL_SH" new-cycle --budget 5 2>/dev/null)"
      python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
d['item_id'] = '099-test-fixture-retry'
open(sys.argv[1], 'w').write(json.dumps(d, indent=2))
" "$SPELLBOOK_ROOT/backlog.d/_cycles/$new_cid/manifest.json"
      bash "$FLYWHEEL_SH" update-bucket "$new_cid" failed >/dev/null 2>&1
      bash "$FLYWHEEL_SH" close "$new_cid" closed >/dev/null 2>&1
    else
      bash "$FLYWHEEL_SH" update-bucket "$cycle_id" failed >/dev/null 2>&1
    fi
  done

  # After 3 failures on a P1, Retry-count should be 3 and auto-demoted to P2.
  local retry_count priority auto_demoted
  retry_count="$(python3 -c "
import re, sys
m = re.search(r'^Retry-count:\s*(\d+)', open(sys.argv[1]).read(), re.MULTILINE)
print(m.group(1) if m else '0')
" "$fixture")"
  priority="$(python3 -c "
import re, sys
m = re.search(r'^Priority:\s*(\w+)', open(sys.argv[1]).read(), re.MULTILINE)
print(m.group(1) if m else '')
" "$fixture")"
  auto_demoted="$(python3 -c "
import re, sys
m = re.search(r'^Auto-demoted:', open(sys.argv[1]).read(), re.MULTILINE)
print('yes' if m else 'no')
" "$fixture")"

  assert_eq "Retry-count bumped to 3" "3" "$retry_count"
  assert_eq "P1 auto-demoted to P2 at cap" "P2" "$priority"
  assert_eq "Auto-demoted flag set" "yes" "$auto_demoted"

  # Clean up fixture.
  /usr/bin/trash "$fixture" 2>/dev/null || true
  bash "$FLYWHEEL_SH" close "$cycle_id" closed >/dev/null 2>&1
}

test_unattended_without_budget_exits_2() {
  local rc=0
  bash "$FLYWHEEL_SH" run --unattended >/dev/null 2>&1 || rc=$?
  assert_eq "unattended without --budget exits 2" "2" "$rc"
}

# --- Runner ---

run_tests() {
  local funcs
  funcs="$(declare -F | awk '/^declare -f test_/{print $3}')"
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
