#!/usr/bin/env bash
# Phase 1 test: config sources cleanly and required vars are valid.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

CFG="$SCRIPTS_DIR/journal-sweep.config"
assert_file "$CFG" "config file exists"

# shellcheck disable=SC1090
. "$CFG"

[ -n "${ROOT:-}" ] && _ok "ROOT set" || _bad "ROOT set"
assert_eq "1" "$([ -d "$ROOT" ] && echo 1 || echo 0)" "ROOT is a directory"
[ -n "${ALLOWLIST:-}" ] && _ok "ALLOWLIST non-empty" || _bad "ALLOWLIST non-empty"
case "$TIMEOUT" in (*[!0-9]*|'') _bad "TIMEOUT numeric";; (*) _ok "TIMEOUT numeric";; esac
case "$CONCURRENCY" in (*[!0-9]*|'') _bad "CONCURRENCY numeric";; (*) _ok "CONCURRENCY numeric";; esac
[ "$CONCURRENCY" -ge 1 ] && _ok "CONCURRENCY >= 1" || _bad "CONCURRENCY >= 1"
[ -n "${MODEL:-}" ] && _ok "MODEL set" || _bad "MODEL set"
[ -n "${PERMISSION_MODE:-}" ] && _ok "PERMISSION_MODE set" || _bad "PERMISSION_MODE set"
[ -n "${LOG:-}" ] && _ok "LOG set" || _bad "LOG set"
[ -n "${STATE_DIR:-}" ] && _ok "STATE_DIR set" || _bad "STATE_DIR set"
# AUTHORS may legitimately be empty (Q8a default).
echo "  info AUTHORS=[${AUTHORS:-}] (empty = any-author staleness)"

finish "config"
