#!/usr/bin/env bash
# Phase 4 test: discover->queue-file dedup, notify-only-on-attention, empty warn.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/fixtures.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
chmod +x "$TESTS_DIR"/claude-shim "$TESTS_DIR"/osascript-shim

BIN="$WORK/bin"; mkdir -p "$BIN"
ln -sf "$TESTS_DIR/claude-shim"    "$BIN/claude"
ln -sf "$TESTS_DIR/osascript-shim" "$BIN/osascript"
export PATH="$BIN:$PATH"

OSA="$WORK/osascript.log"; : > "$OSA"; export OSASCRIPT_SHIM_LOG="$OSA"
QUEUE="$WORK/discover-queue.md"

cat > "$WORK/cfg" <<EOF
ROOT=/unused
ALLOWLIST="stonematt"
TIMEOUT=10
CONCURRENCY=2
MODEL=sonnet
PERMISSION_MODE=bypassPermissions
AUTHORS=""
LOG=$WORK/log
STATE_DIR=$WORK/state
DISCOVER_QUEUE=$QUEUE
NOTIFY=1
EOF
SEEN="$WORK/state/seen-repos"
run() { JOURNAL_SWEEP_TODAY=2026-06-18 bash "$SCRIPTS_DIR/journal-sweep.sh" --config "$WORK/cfg" --root "$1"; }

# ---- Scenario A: fresh run -> dispatch, discover->queue, notify -----------
SBX="$WORK/sbx"; build_fixtures "$SBX"
A="$(run "$SBX" 2>/dev/null)"
assert_contains "$A" "DISCOVER(new) github.com/stonematt/discover-me" "new owned repo surfaced"
assert_contains "$A" "EMPTY github.com/stonematt/empty-journal" "empty journal warned, not dispatched"
assert_contains "$A" "RESULT ok github.com/stonematt/stale-repo" "stale repo dispatched ok"
assert_file "$QUEUE" "discover queue file created"
assert_eq "1" "$(grep -c 'discover-me' "$QUEUE")" "exactly one queue entry for discover-me"
assert_eq "1" "$([ -n "$(cat "$OSA")" ] && echo 1 || echo 0)" "notify fired (new discover = attention)"
assert_eq "1" "$(grep -cxF 'github.com/stonematt/discover-me' "$SEEN")" "discover-me recorded in seen-repos"

# ---- Scenario B: re-run -> entries now current, discover deduped, silent --
: > "$OSA"
B="$(run "$SBX" 2>/dev/null)"
assert_contains "$B" "no stale repos" "all repos current after first sweep (idempotent)"
assert_not_contains "$B" "DISCOVER(new)" "discover-me NOT re-surfaced (dedup)"
assert_eq "1" "$(grep -c 'discover-me' "$QUEUE")" "no new queue entry on re-run (dedup honored)"
assert_contains "$B" "clean run — no notification" "clean run reported"
assert_eq "0" "$([ -n "$(cat "$OSA")" ] && echo 1 || echo 0)" "notify silent on clean run"

# ---- Scenario C: failure (no new discover) -> notify fires ----------------
SBX2="$WORK/sbx2"; build_fixtures "$SBX2"
printf 'github.com/stonematt/discover-me\n' >> "$SEEN"  # pre-seed so discover isn't new
: > "$OSA"
export SHIM_FAIL_REPO="stale-repo"
C="$(run "$SBX2" 2>/dev/null)"
unset SHIM_FAIL_REPO
assert_contains "$C" "RESULT failed github.com/stonematt/stale-repo" "forced failure recorded"
assert_not_contains "$C" "DISCOVER(new)" "no new discover this run"
assert_eq "1" "$([ -n "$(cat "$OSA")" ] && echo 1 || echo 0)" "notify fired on failure alone"

finish "outputs"
