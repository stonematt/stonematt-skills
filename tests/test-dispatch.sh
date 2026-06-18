#!/usr/bin/env bash
# Phase 3 test: dispatch invokes the right repos/ranges, skips-and-continues on
# failure/timeout, and respects the concurrency cap. Uses the fake claude-shim.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/fixtures.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
chmod +x "$TESTS_DIR"/claude-shim "$TESTS_DIR"/osascript-shim

# Build a temp config (real ROOT overridden per-run via --root).
mkcfg() { # timeout concurrency
  cat > "$WORK/cfg" <<EOF
ROOT=/unused
ALLOWLIST="stonematt"
TIMEOUT=$1
CONCURRENCY=$2
MODEL=sonnet
PERMISSION_MODE=bypassPermissions
AUTHORS=""
LOG=$WORK/log
STATE_DIR=$WORK/state
OBSIDIAN_VAULT=tyee
INBOX_DIR=0.inbox
NOTIFY=0
EOF
}

# Fake external commands on PATH (claude dispatch + osascript that notify() may
# call — keep the real osascript out).
BIN="$WORK/bin"; mkdir -p "$BIN"
ln -sf "$TESTS_DIR/claude-shim"    "$BIN/claude"
ln -sf "$TESTS_DIR/osascript-shim" "$BIN/osascript"
export PATH="$BIN:$PATH"

run_sweep() { # sandbox config
  JOURNAL_SWEEP_TODAY=2026-06-18 bash "$SCRIPTS_DIR/journal-sweep.sh" \
    --config "$2" --root "$1"
}

# ---- Run 1: behavior + ranges + skip-and-continue -------------------------
S1="$WORK/s1"; build_fixtures "$S1"
mkcfg 2 2
: > "$WORK/shimlog"
export SHIM_LOG="$WORK/shimlog" SHIM_FAIL_REPO="gap-repo" SHIM_HANG_REPO="localonly"
GOT1="$(run_sweep "$S1" "$WORK/cfg" 2>/dev/null)"
unset SHIM_LOG SHIM_FAIL_REPO SHIM_HANG_REPO

assert_contains "$GOT1" "RESULT ok github.com/stonematt/stale-repo 2026-06-14..2026-06-17" "ok repo dispatched with correct range"
assert_contains "$GOT1" "RESULT failed github.com/stonematt/gap-repo 2026-05-31..2026-06-17" "failing repo marked failed (skip-and-continue)"
assert_contains "$GOT1" "RESULT timeout localonly 2026-06-16..2026-06-17" "hung repo killed at timeout -> timeout"
# all three attempted despite one failure + one hang
N=$(grep -c '^CWD=' "$WORK/shimlog")
assert_eq "3" "$N" "all 3 stale repos attempted (batch not aborted)"
# prompts carry detector-computed ranges
assert_contains "$(cat "$WORK/shimlog")" "for 2026-06-14 through 2026-06-17" "stale-repo prompt range correct"
assert_contains "$(cat "$WORK/shimlog")" "for 2026-05-31 through 2026-06-17" "gap-repo prompt range correct"

# ---- Run 2: concurrency cap ------------------------------------------------
S2="$WORK/s2"; build_fixtures "$S2"
mkcfg 10 2
echo 0 > "$WORK/cur"; echo 0 > "$WORK/max"; rm -rf "$WORK/lock"
export SHIM_CUR="$WORK/cur" SHIM_MAX="$WORK/max" SHIM_LOCK="$WORK/lock" SHIM_SLEEP=0.5
run_sweep "$S2" "$WORK/cfg" >/dev/null 2>&1
unset SHIM_CUR SHIM_MAX SHIM_LOCK SHIM_SLEEP
MAX=$(cat "$WORK/max")
assert_le "$MAX" "2" "max concurrent <= CONCURRENCY(2)"
assert_eq "2" "$MAX" "parallelism actually occurred (max hit cap of 2)"

finish "dispatch"
