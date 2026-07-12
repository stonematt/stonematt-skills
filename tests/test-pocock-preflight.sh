#!/usr/bin/env bash
# Preflight wiring gate (#54): refuses downstream Pocock skills on unwired state.
# The gate consumes the pocock-plan emitter (single detection authority) and
# renders a PASS/FAIL verdict + config-reconcile-first guidance.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_fixtures "$SANDBOX"

GATE="$SCRIPTS_DIR/pocock-preflight.sh"

run_gate() { bash "$GATE" --root "$SANDBOX/$1" 2>&1; }
gate_rc()  { bash "$GATE" --root "$SANDBOX/$1" >/dev/null 2>&1; echo $?; }

# ---- wired repo => PASS ----------------------------------------------------
OUT="$(run_gate wired)"
assert_eq 0 "$(gate_rc wired)" "wired repo => gate exits 0"
assert_contains "$OUT" "GATE: PASS" "wired repo => PASS verdict"

# ---- greenfield (no config) => FAIL, reconcile-first guidance ---------------
OUT="$(run_gate greenfield)"
assert_eq 1 "$(gate_rc greenfield)" "greenfield => gate exits 1"
assert_contains "$OUT" "GATE: FAIL"              "greenfield => FAIL verdict"
assert_contains "$OUT" "issue-tracker.md missing" "greenfield => flags missing tracker doc"
assert_contains "$OUT" "reconcile config FIRST"   "miss => reconcile config first"
assert_contains "$OUT" "THEN audit"               "miss => then audit the wrapping layer"
assert_contains "$OUT" "Never audit-only"         "miss => never audit-only"
# "map built successfully" is not proof of wiring — the gate says so explicitly.
assert_contains "$OUT" "NOT proof of correct wiring" "map success is not proof of wiring"

# ---- provisional tracker doc => FAIL ---------------------------------------
OUT="$(run_gate provisional)"
assert_eq 1 "$(gate_rc provisional)" "provisional banner => gate exits 1"
assert_contains "$OUT" "provisional / not reconciled" "provisional => flags unreconciled tracker"

# ---- stale v1.0 slug present => FAIL ---------------------------------------
OUT="$(run_gate stale)"
assert_eq 1 "$(gate_rc stale)" "stale slug => gate exits 1"
assert_contains "$OUT" "stale v1.0 slug references present" "stale => flags v1.0 slugs"

# ---- missing triage/domain docs => FAIL ------------------------------------
OUT="$(run_gate missing-docs)"
assert_eq 1 "$(gate_rc missing-docs)" "missing triage/domain => gate exits 1"
assert_contains "$OUT" "triage-labels.md missing" "missing-docs => flags triage-labels"
assert_contains "$OUT" "domain.md missing"        "missing-docs => flags domain"

# ---- detection is NOT duplicated: gate reuses the emitter -------------------
# The gate must call pocock-plan.sh rather than re-scan the tree itself.
assert_contains "$(cat "$GATE")" "pocock-plan.sh" "gate reuses the T1 emitter for detection"

# ---- --json verdict --------------------------------------------------------
JOUT="$(bash "$GATE" --json --root "$SANDBOX/wired" 2>/dev/null)"
assert_contains "$JOUT" '"gate": "pass"' "wired => json gate pass"
if printf '%s\n' "$JOUT" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "json verdict is valid JSON"
else
  _bad "json verdict is not valid JSON"
fi
JFAIL="$(bash "$GATE" --json --root "$SANDBOX/greenfield" 2>/dev/null)"
assert_contains "$JFAIL" '"gate": "fail"' "greenfield => json gate fail"

finish "pocock-preflight"
