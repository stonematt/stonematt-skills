#!/usr/bin/env bash
# Phase 5/6 test: single-instance lock — held by a live process blocks a second
# run; a stale (dead-PID) lock is reclaimed.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"; [ -n "${SLEEP_PID:-}" ] && kill "$SLEEP_PID" 2>/dev/null' EXIT
EMPTY="$WORK/empty"; mkdir -p "$EMPTY"
STATE="$WORK/state"; mkdir -p "$STATE"

cat > "$WORK/cfg" <<EOF
ROOT=/unused
ALLOWLIST="stonematt"
TIMEOUT=5
CONCURRENCY=2
MODEL=sonnet
PERMISSION_MODE=bypassPermissions
AUTHORS=""
LOG=$WORK/log
STATE_DIR=$STATE
OBSIDIAN_VAULT=tyee
INBOX_DIR=0.inbox
NOTIFY=0
EOF
run() { JOURNAL_SWEEP_TODAY=2026-06-18 bash "$SCRIPTS_DIR/journal-sweep.sh" --config "$WORK/cfg" --root "$EMPTY"; }

# ---- live lock -> second run backs off ------------------------------------
sleep 30 & SLEEP_PID=$!
mkdir -p "$STATE/lock.d"; printf '%s\n' "$SLEEP_PID" > "$STATE/lock.d/pid"
OUT="$(run 2>&1)"
assert_contains "$OUT" "holds the lock — exiting" "live lock blocks a second run"
kill "$SLEEP_PID" 2>/dev/null; SLEEP_PID=""

# ---- stale lock (dead PID) -> reclaimed -----------------------------------
mkdir -p "$STATE/lock.d"; printf '%s\n' "999999" > "$STATE/lock.d/pid"
OUT2="$(run 2>&1)"
assert_not_contains "$OUT2" "holds the lock" "stale lock reclaimed (not blocked)"
assert_contains "$OUT2" "journal-sweep run" "run proceeded after reclaiming stale lock"

finish "lock"
