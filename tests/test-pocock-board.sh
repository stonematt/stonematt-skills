#!/usr/bin/env bash
# Seam 2 (#62): the single Projects-v2 GraphQL helper the adopt-Pocock model
# calls. Offline, fixture-free, no network — deterministic input maps to the
# correct GraphQL/mutation payloads via the gh shims:
#   status-field  overwrite the un-deletable built-in Status field in place +
#                 capture field id + option ids
#   backfill      addProjectV2ItemById + updateProjectV2ItemFieldValue per issue
#   labels        idempotent gh label create of the canonical vocabulary
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# The board helper now rides INSIDE the skill dir (bundled so the skill is
# self-contained on any target repo — #77), not in the repo-root scripts/ dir.
BOARD="$(cd "$TESTS_DIR/../skills/in-progress/stone-adopt-pocock/scripts" && pwd)/pocock-board.sh"
SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT

chmod +x "$TESTS_DIR/gh-board-shim" "$TESTS_DIR/gh-label-shim"

# ---- status-field: overwrite the built-in Status field in place ------------
GQL="$SANDBOX/status.gql.log"; : > "$GQL"
SOUT="$(POCOCK_GH="$TESTS_DIR/gh-board-shim" GH_GQL_LOG="$GQL" \
  bash "$BOARD" status-field --field-id F_INPUT 2>&1)"
assert_eq 0 "$?" "status-field exits 0"

SLOG="$(cat "$GQL")"
# The un-deletable built-in field is overwritten in place (not deleted).
assert_contains "$SLOG" "updateProjectV2Field"     "status-field => calls updateProjectV2Field"
assert_not_contains "$SLOG" "deleteProjectV2Field" "status-field => never deletes the built-in field"
# The whole option set is replaced.
assert_contains "$SLOG" "singleSelectOptions"      "status-field => replaces the whole option set"
# The input field id is bound to the mutation.
assert_contains "$SLOG" "field=F_INPUT"            "status-field => binds the input --field-id"
# The captured field id + option ids are emitted as JSON for the CI sync.
if printf '%s\n' "$SOUT" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "status-field => emits valid JSON capture"
else
  _bad "status-field => emits valid JSON capture"
fi
assert_contains "$SOUT" '"status_field_id": "FIELD_STATUS"' "status-field => captures the field id"
assert_contains "$SOUT" '"Triage": "opt_triage"'   "status-field => captures the Triage option id"
assert_contains "$SOUT" '"Released": "opt_released"' "status-field => captures the Released option id"

# ---- backfill: add each issue to the board + set its Status ------------------
GQL2="$SANDBOX/backfill.gql.log"; : > "$GQL2"
BOUT="$(printf '%s\n' 'ISSUE_A opt_triage' '# a comment' '' 'ISSUE_B opt_wip' | \
  POCOCK_GH="$TESTS_DIR/gh-board-shim" GH_GQL_LOG="$GQL2" \
  bash "$BOARD" backfill --project-id PROJ_1 --field-id F_STATUS 2>&1)"
assert_eq 0 "$?" "backfill exits 0"

BLOG="$(cat "$GQL2")"
# Two issues (blank + comment lines skipped) => two add + two update mutations.
assert_contains "$BLOG" "addProjectV2ItemById"          "backfill => adds items via addProjectV2ItemById"
assert_contains "$BLOG" "updateProjectV2ItemFieldValue" "backfill => sets Status via updateProjectV2ItemFieldValue"
assert_contains "$BLOG" "singleSelectOptionId"          "backfill => sets the single-select option value"
# Correct field bindings flow through: board, issue content, field, option.
assert_contains "$BLOG" "project=PROJ_1"   "backfill => binds the project id"
assert_contains "$BLOG" "content=ISSUE_A"  "backfill => binds the first issue node id"
assert_contains "$BLOG" "content=ISSUE_B"  "backfill => binds the second issue node id"
assert_contains "$BLOG" "field=F_STATUS"   "backfill => binds the status field id"
assert_contains "$BLOG" "option=opt_triage" "backfill => binds the first mapped option id"
assert_contains "$BLOG" "option=opt_wip"    "backfill => binds the second mapped option id"
# Item id captured from the add response is threaded into the field update.
assert_contains "$BLOG" "item=ITEM_NEW"    "backfill => threads the captured item id into the update"
ADDS="$(grep -c "addProjectV2ItemById" "$GQL2")"
assert_eq 2 "$ADDS" "backfill => exactly one add per non-blank input line"

# ---- labels: idempotent canonical vocabulary --------------------------------
LOG="$SANDBOX/labels.log"; : > "$LOG"
LOUT="$(POCOCK_GH="$TESTS_DIR/gh-label-shim" GH_LABEL_LOG="$LOG" \
  bash "$BOARD" labels 2>&1)"
assert_eq 0 "$?" "labels exits 0"

LLOG="$(cat "$LOG")"
assert_contains "$LLOG" "status: triage"  "labels => creates status: triage"
assert_contains "$LLOG" "status: ready"   "labels => creates status: ready"
assert_contains "$LLOG" "status: wip"     "labels => creates status: wip"
assert_contains "$LLOG" "status: staged"  "labels => creates status: staged"
assert_contains "$LLOG" "status: blocked" "labels => creates status: blocked"
assert_contains "$LLOG" "afk"             "labels => creates the afk flag"
assert_contains "$LLOG" "needs-info"      "labels => creates the needs-info facet"
# Released is label-less (the closed state) — never a label.
assert_not_contains "$LLOG" "released"    "labels => never creates a released label (label-less closed state)"

# ---- usage: unknown command / no command is a usage error (exit 2) ----------
bash "$BOARD" bogus >/dev/null 2>&1
assert_eq 2 "$?" "unknown command exits 2"
bash "$BOARD" >/dev/null 2>&1
assert_eq 2 "$?" "no command exits 2"

# ---- decoupling: no residual reference to the deleted detection scripts ------
SRC="$(cat "$BOARD")"
assert_not_contains "$SRC" "pocock-""plan"  "helper no longer couples to the deleted plan emitter"
assert_not_contains "$SRC" "board_scope"  "helper no longer branches on board_scope (model judgment now)"
assert_not_contains "$SRC" "audit-sweep"  "helper no longer carries the audit sweep"
assert_not_contains "$SRC" "project-sync.yml" "helper no longer projects the CI workflow files (slice #64)"

finish "pocock-board"
