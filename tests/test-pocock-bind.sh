#!/usr/bin/env bash
# Live role-binding test (issue #53): pocock-bind discovers bindings from the
# installed suite in authority order, narrows to the tracker-touching roles,
# stops-and-surfaces on an ambiguous/empty bind, flags forked commit/merge
# skills, and — on the current suite — reproduces the static table (pure expand).
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-suite-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_suite_fixtures "$SANDBOX"

# ---- AC6: current suite reproduces the static table (pure expand) ----------
GOLDEN="$TESTS_DIR/golden/pocock-bind-current.yaml"
GOT="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/current" --format bindings-block)"
RC=$?
assert_eq 0 "$RC" "current-suite bind exits 0 (all roles resolved)"
WANT="$(cat "$GOLDEN")"
if [ "$GOT" = "$WANT" ]; then
  _ok "current-suite bindings match the static table (pure expand)"
else
  _bad "current-suite bindings drifted from the static table"
  echo "---- diff (< want / > got) ----"
  diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$GOT")
fi

# ---- AC2: only the seven tracker-touching roles are bound ------------------
RECIPE="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/current")"
BOUND_ROLES="$(printf '%s\n' "$RECIPE" | awk '/^bindings:/{f=1;next} /^[^ ]/{f=0} f{print $1}')"
assert_eq "7" "$(printf '%s\n' "$BOUND_ROLES" | grep -c .)" "exactly seven roles bound (narrow scope)"
for role in "on-ramp:" "spec:" "slice-to-tickets:" "implement:" "review:" "setup:" "wayfinder:"; do
  assert_contains "$BOUND_ROLES" "$role" "tracker-touching role bound: $role"
done
# Non-tracker roles are never bound (idea-sharpening, vocabulary-layer, etc.).
assert_not_contains "$RECIPE" "idea-sharpening" "non-tracker role NOT bound"
assert_not_contains "$RECIPE" "vocabulary-layer" "vocabulary-layer role NOT bound"

# ---- AC5: recipe carries the version delta (cacheable per-version) ---------
assert_contains "$RECIPE" "version: 1.4.0"        "recipe records the suite version"
assert_contains "$RECIPE" "version_delta:"        "recipe carries a version delta"
DELTA_BUMP="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/current" --prior-version 1.1.0 --format delta)"
assert_contains "$DELTA_BUMP" "bumped: 1.1.0 -> 1.4.0" "version delta reflects the prior stamp"

# ---- AC1: authority order — release notes resolve a rename ----------------
RENAMED="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/renamed")"
RRC=$?
assert_eq 0 "$RRC" "renamed suite binds (release-notes authority) exits 0"
assert_contains "$RENAMED" "spec: spec-it"        "release notes bind spec -> spec-it (authority 1)"
assert_contains "$RENAMED" "spec: release-notes"  "spec binding sourced from release-notes"

# ---- AC1: authority order — ask-matt breaks an otherwise-ambiguous tie -----
RESCUE="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/ask-matt-rescue")"
XRC=$?
assert_eq 0 "$XRC" "ask-matt disambiguates an otherwise-ambiguous split (exit 0)"
assert_contains "$RESCUE" "review: code-review" "ask-matt resolves review -> code-review"
assert_contains "$RESCUE" "review: ask-matt"    "review binding sourced from ask-matt (authority 3)"

# ---- AC3: ambiguous split -> stop-and-surface, no bind cached --------------
SPLIT_OUT="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/split" 2>&1)"
SRC=$?
assert_eq 4 "$SRC" "ambiguous split stops-and-surfaces (exit 4)"
assert_contains "$SPLIT_OUT" "STOP"      "split run surfaces a STOP report"
assert_contains "$SPLIT_OUT" "ambiguous" "split report names the ambiguity"
SPLIT_STDOUT="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/split" 2>/dev/null)"
assert_eq "" "$SPLIT_STDOUT" "no recipe emitted on stop-and-surface (no silent auto-bind)"

# ---- AC3: vanished role (empty bind) -> stop-and-surface -------------------
VAN_OUT="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/vanished" 2>&1)"
VRC=$?
assert_eq 4 "$VRC" "vanished role stops-and-surfaces (exit 4)"
assert_contains "$VAN_OUT" "empty" "vanished-role report names the empty bind"

# ---- AC4: forked commit/merge skills flagged, never bound ------------------
FORKED="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/forked")"
FRC=$?
assert_eq 0 "$FRC" "forked-suite bind still resolves the tracker roles (exit 0)"
assert_contains "$FORKED" "forked_flags:" "forked skills surfaced in a flags list"
assert_contains "$FORKED" "stone-commit"  "forked commit skill flagged"
assert_contains "$FORKED" "stone-merge"   "forked merge skill flagged"
# Flagged, never bound to a role — no role maps onto a stone-* fork.
BOUND_ONLY="$(printf '%s\n' "$FORKED" | awk '/^bindings:/{f=1;next} /^[^ ]/{f=0} f{print}')"
assert_not_contains "$BOUND_ONLY" "stone-commit" "forked commit skill never bound to a role"
assert_not_contains "$BOUND_ONLY" "stone-merge"  "forked merge skill never bound to a role"

# ---- no suite -> refuse (exit 3) ------------------------------------------
bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$SANDBOX/does-not-exist" >/dev/null 2>&1
assert_eq 3 "$?" "missing suite refuses (exit 3)"

finish "pocock-bind"
