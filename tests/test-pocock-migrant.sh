#!/usr/bin/env bash
# Migrant + version-stamp-freshness + drift-audit seam (#52).
#
# The stamp gives the fast current-vs-migrant decision; the slug-scan is the
# belt-and-suspenders that flags migrant with no stamp; migrant parses the stamp,
# diffs it against the installed suite, and writes a dated, grouped drift report.
# Detection authority stays with pocock-plan — this seam only parses + diffs.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_fixtures "$SANDBOX"

MIGRANT="$SCRIPTS_DIR/pocock-migrant.sh"

# Deterministic drift math: injected installed suite + fixed date/version.
export POCOCK_INSTALLED_CATALOG="$SANDBOX/installed-catalog.json"
export POCOCK_INSTALLED_VERSION="1.4.0"
export POCOCK_DRIFT_DATE="2026-07-12"

run()  { bash "$MIGRANT" --root "$SANDBOX/$1" 2>&1; }
jrun() { bash "$MIGRANT" --json --root "$SANDBOX/$1" 2>/dev/null; }
rc()   { bash "$MIGRANT" --root "$SANDBOX/$1" >/dev/null 2>&1; echo $?; }

# ---- detection is NOT duplicated: the seam reuses the emitter ---------------
assert_contains "$(cat "$MIGRANT")" "pocock-plan.sh" "migrant reuses the plan emitter for freshness"

# ---- AC: stamp parsed (version, source, catalog-light map, bindings) --------
J="$(jrun migrant-stale-stamp)"
assert_contains "$J" '"version": "1.1.0"'      "stamp version parsed"
assert_contains "$J" '"source": "~/.agents/skills"' "stamp source parsed"
assert_contains "$J" '"to-review"'             "stamp catalog-light map parsed (name)"
assert_contains "$J" '"review to-review"'      "stamp bindings parsed (role -> skill)"
if printf '%s\n' "$J" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "migrant --json is valid JSON"
else
  _bad "migrant --json is not valid JSON"
fi

# ---- AC: freshness — stamp == installed => current (near-noop patch) --------
OUT="$(run current)"
assert_eq 0 "$(rc current)" "current => exits 0"
assert_contains "$OUT" "current" "stamp == installed => current verdict"
assert_contains "$OUT" "near-noop" "current => near-noop patch"
assert_nofile "$SANDBOX/current/docs/agents/pocock-drift-$POCOCK_DRIFT_DATE.md" \
  "current writes NO drift file"
JC="$(jrun current)"
assert_contains "$JC" '"freshness": "current"' "current json freshness"
assert_contains "$JC" '"action": "patch"'      "current json action patch"

# ---- AC: stale-stamp (version drift) => migrant -----------------------------
assert_contains "$(jrun migrant-stale-stamp)" '"freshness": "migrant"' "stale stamp => migrant"

# ---- AC: slug-scan flags migrant even with NO stamp -------------------------
JN="$(jrun migrant-no-stamp)"
assert_contains "$JN" '"freshness": "migrant"' "no stamp + v1.0 slugs => migrant"
assert_contains "$JN" '"version": null'        "no-stamp repo => null stamp version"
assert_contains "$JN" '"to-prd"'  "no-stamp migrant carries to-prd stale ref"
assert_contains "$JN" '"to-issues"' "no-stamp migrant carries to-issues stale ref"

# ---- AC: migrant flow ordering — config first, then wrapping layer ----------
# Both the JSON steps and the report echo must put reconcile-config BEFORE the
# wrapping-layer rewrite (audit-only / find-and-replace-only are the failures).
STEPS="$(jrun migrant-stale-stamp | python3 -c 'import json,sys;print(",".join(json.load(sys.stdin)["steps"]))')"
assert_eq "reconcile-config,wrapping-layer-rewrite" "$STEPS" "steps: config first, then wrapping layer"

OUTM="$(run migrant-stale-stamp)"
CFG_LINE="$(printf '%s\n' "$OUTM" | grep -n 'reconcile config first' | head -1 | cut -d: -f1)"
WRAP_LINE="$(printf '%s\n' "$OUTM" | grep -n 'wrapping-layer rewrite' | head -1 | cut -d: -f1)"
if [ -n "$CFG_LINE" ] && [ -n "$WRAP_LINE" ] && [ "$CFG_LINE" -lt "$WRAP_LINE" ]; then
  _ok "echo orders reconcile-config before wrapping-layer rewrite"
else
  _bad "echo ordering wrong (cfg=$CFG_LINE wrap=$WRAP_LINE)"
fi

# ---- AC: dated drift file, six drift groups + session echo ------------------
assert_eq 0 "$(rc migrant-stale-stamp)" "migrant => exits 0"
DRIFT="$SANDBOX/migrant-stale-stamp/docs/agents/pocock-drift-$POCOCK_DRIFT_DATE.md"
assert_file "$DRIFT" "dated drift file written"
DBODY="$(cat "$DRIFT")"
for h in "### Renamed / merged" "### Contract-changed" "### Added" \
         "### Removed" "### Bindings-shifted" "### Stale refs"; do
  assert_contains "$DBODY" "$h" "drift report groups: $h"
done
assert_contains "$OUTM" "drift report written" "session echo announces the drift report"

# ---- goldens green: drift report matches golden byte-for-byte ---------------
golden_check() { # fixture goldenfile msg
  local got="$SANDBOX/$1/docs/agents/pocock-drift-$POCOCK_DRIFT_DATE.md"
  local want="$TESTS_DIR/golden/$2"
  if diff -q "$want" "$got" >/dev/null 2>&1; then
    _ok "$3"
  else
    _bad "$3"
    echo "---- diff (< want / > got) ----"; diff "$want" "$got"
  fi
}
run migrant-no-stamp >/dev/null
golden_check migrant-stale-stamp pocock-drift-stale-stamp.md "stale-stamp drift matches golden"
golden_check migrant-no-stamp    pocock-drift-no-stamp.md    "no-stamp drift matches golden"

# ---- greenfield is NOT this seam's job (belongs to pocock-apply) ------------
assert_eq 3 "$(rc greenfield)" "greenfield => refused (exit 3), that is apply's job"

finish "pocock-migrant"
