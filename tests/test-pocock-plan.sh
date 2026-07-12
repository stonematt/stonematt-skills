#!/usr/bin/env bash
# Plan-emitter test: greenfield tracker-backed plan matches golden, mutates nothing.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_fixtures "$SANDBOX"

REPO="$SANDBOX/greenfield"
GOLDEN="$TESTS_DIR/golden/pocock-greenfield.json"

# Capture pre-run tree state so we can prove the seam mutates nothing.
BEFORE="$(git -C "$REPO" status --porcelain)"

GOT="$(bash "$SCRIPTS_DIR/pocock-plan.sh" --dry-run --json --root "$REPO" 2>/dev/null)"
RC=$?

assert_eq 0 "$RC" "plan-emitter exits 0"

# Golden diff — the tested seam.
WANT="$(cat "$GOLDEN")"
if [ "$GOT" = "$WANT" ]; then
  _ok "greenfield plan matches golden"
else
  _bad "greenfield plan mismatch"
  echo "---- diff (< want / > got) ----"
  diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$GOT")
fi

# Emitted plan is valid JSON.
if printf '%s\n' "$GOT" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "plan is valid JSON"
else
  _bad "plan is not valid JSON"
fi

# Classification assertions the golden asserts, restated for signal on failure.
assert_contains "$GOT" '"substrate": "tracker-backed"' "greenfield origin repo => tracker-backed"
assert_contains "$GOT" '"freshness": "greenfield"'      "bare repo (no config) => greenfield"
assert_contains "$GOT" '"stamp_version": null'          "no stamp => null version"
assert_contains "$GOT" '"stale_slugs": []'              "no v1.0 slugs => empty stale list"
assert_contains "$GOT" '"cached_bindings": null'        "greenfield => nothing cached, discover live"

# Every acceptance-required key is present in the plan.
for key in substrate freshness stamp_version stale_slugs proposed_slots \
           cached_bindings artifacts_to_write labels_to_create; do
  assert_contains "$GOT" "\"$key\":" "plan carries \"$key\""
done

# Seam mutates nothing: no working-tree changes and no new files.
AFTER="$(git -C "$REPO" status --porcelain)"
assert_eq "$BEFORE" "$AFTER" "dry-run leaves the repo untouched"

finish "pocock-plan"
