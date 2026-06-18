#!/usr/bin/env bash
# Phase 6 test: full pipeline (shim-driven, deterministic) + the two AFK-safety
# evals — IDEMPOTENCY and TODAY-EXCLUSION.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/fixtures.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
chmod +x "$TESTS_DIR"/claude-shim "$TESTS_DIR"/osascript-shim
BIN="$WORK/bin"; mkdir -p "$BIN"
for c in claude osascript; do ln -sf "$TESTS_DIR/$c-shim" "$BIN/$c"; done
export PATH="$BIN:$PATH"

cat > "$WORK/cfg" <<EOF
ROOT=/unused
ALLOWLIST="stonematt"
TIMEOUT=10
CONCURRENCY=3
MODEL=sonnet
PERMISSION_MODE=bypassPermissions
AUTHORS=""
LOG=$WORK/log
STATE_DIR=$WORK/state
OBSIDIAN_VAULT=tyee
INBOX_DIR=0.inbox
NOTIFY=1
EOF
SBX="$WORK/sbx"; build_fixtures "$SBX"
: > "$WORK/shimlog"; export SHIM_LOG="$WORK/shimlog"
run() { JOURNAL_SWEEP_TODAY=2026-06-18 bash "$SCRIPTS_DIR/journal-sweep.sh" --config "$WORK/cfg" --root "$SBX"; }

# ---- Run A: full pipeline -------------------------------------------------
A="$(run 2>/dev/null)"
assert_contains "$A" "dispatching 3 stale repo(s)" "3 stale repos dispatched"
assert_contains "$A" "DISCOVER(new) github.com/stonematt/discover-me" "owned-no-journal surfaced"
assert_contains "$A" "EMPTY github.com/stonematt/empty-journal" "empty journal warned"
assert_file "$SBX/github.com/stonematt/stale-repo/.journal/docs/journal/2026-06-17.md" "stale-repo entry written for yesterday"
assert_file "$SBX/github.com/stonematt/gap-repo/.journal/docs/journal/2026-06-17.md" "gap-repo entry written"
COUNT_A=$(grep -c '^CWD=' "$WORK/shimlog")
assert_eq "3" "$COUNT_A" "exactly 3 dispatches in run A"

# ---- TODAY-EXCLUSION ------------------------------------------------------
assert_not_contains "$A" "today-only" "today-only repo never dispatched"
# No entry is EVER created for today (2026-06-18) in any repo.
TODAY_ENTRIES=$(ls "$SBX"/*/*/*/.journal/docs/journal/2026-06-18.md \
                   "$SBX"/*/.journal/docs/journal/2026-06-18.md 2>/dev/null | wc -l | tr -d ' ')
assert_eq "0" "$TODAY_ENTRIES" "no journal entry created for today (in-progress day excluded)"

# ---- IDEMPOTENCY: immediate re-run dispatches nothing ---------------------
B="$(run 2>/dev/null)"
assert_contains "$B" "no stale repos" "run B finds nothing stale (idempotent)"
assert_not_contains "$B" "DISCOVER(new)" "discover deduped on re-run"
COUNT_B=$(grep -c '^CWD=' "$WORK/shimlog")
assert_eq "$COUNT_A" "$COUNT_B" "re-run added zero dispatches (no re-journaling)"

finish "e2e"
