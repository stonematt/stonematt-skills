#!/usr/bin/env bash
# Phase 2 test: detector classification matches golden across all cases.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_fixtures "$SANDBOX"

GOT="$(JOURNAL_SWEEP_TODAY=2026-06-18 bash "$SCRIPTS_DIR/journal-sweep.sh" \
        --dry-run --json --root "$SANDBOX" 2>/dev/null)"

read -r -d '' WANT <<'EOF'
{"repo":"github.com/randovendor/foreign","action":"ignore","owner":"randovendor"}
{"repo":"github.com/stonematt/current-repo","action":"current"}
{"repo":"github.com/stonematt/discover-me","action":"discover","owner":"stonematt"}
{"repo":"github.com/stonematt/empty-journal","action":"empty"}
{"repo":"github.com/stonematt/gap-repo","action":"stale","start":"2026-05-31","end":"2026-06-17"}
{"repo":"github.com/stonematt/stale-repo","action":"stale","start":"2026-06-14","end":"2026-06-17"}
{"repo":"github.com/stonematt/today-only","action":"current"}
{"repo":"localonly","action":"stale","start":"2026-06-16","end":"2026-06-17"}
EOF

if [ "$GOT" = "$WANT" ]; then
  _ok "detector output matches golden"
else
  _bad "detector output mismatch"
  echo "---- diff (< want / > got) ----"
  diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$GOT")
fi

# Spot assertions for the high-value safety cases.
assert_not_contains "$GOT" "linked-worktree" "linked worktree (.git file) NOT treated as repo"
assert_not_contains "$GOT" "nested"          "nested repo under a root NOT emitted (pruned)"
assert_not_contains "$GOT" "vendor/sub"      "submodule (.git file) NOT emitted (pruned)"
assert_contains "$GOT" 'today-only","action":"current"' "today-only work excluded (no dispatch for today)"

finish "detector"
