#!/usr/bin/env bash
# Multi-repo member mode (#58): on a member of a shared org board the wrapper
# applies the UNIFORM spine (the same status:* vocabulary — forced over a
# surveyed flat state), SKIPS the end-of-run board/CI prompt, keeps board
# automation decoupled per-member, and never scaffolds the org itself. This test
# pins the deterministic member-mode seam (pocock-member.sh) + the board_scope
# detection the plan emitter now carries.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_fixtures "$SANDBOX"

PLAN="$SCRIPTS_DIR/pocock-plan.sh"
MEMBER="$SCRIPTS_DIR/pocock-member.sh"
ORG="acme-collective"

# ---- board_scope detection off the plan emitter ----------------------------
# With POCOCK_SHARED_ORGS matching the member repo's org owner, the plan
# proposes board_scope=shared; unset, it stays own (the safe default).
MPLAN_SHARED="$(POCOCK_SHARED_ORGS="$ORG" bash "$PLAN" --dry-run --json --root "$SANDBOX/member" 2>/dev/null)"
assert_contains "$MPLAN_SHARED" '"board_scope": "shared"' "org owner in POCOCK_SHARED_ORGS => plan proposes shared"

MPLAN_DEFAULT="$(bash "$PLAN" --dry-run --json --root "$SANDBOX/member" 2>/dev/null)"
assert_contains "$MPLAN_DEFAULT" '"board_scope": "own"' "no POCOCK_SHARED_ORGS => plan proposes own"

# A personal (own) repo never mis-detects as a member, even under the env knob.
GPLAN="$(POCOCK_SHARED_ORGS="$ORG" bash "$PLAN" --dry-run --json --root "$SANDBOX/board" 2>/dev/null)"
assert_contains "$GPLAN" '"board_scope": "own"' "non-org owner stays own under the env knob"

# ---- member seam: shared scope => the uniform spine, forced ----------------
MOUT="$(POCOCK_SHARED_ORGS="$ORG" bash "$MEMBER" --root "$SANDBOX/member" 2>&1)"
assert_eq 0 "$?" "member seam exits 0"

# AC1 — uniform spine incl. the SAME status:* vocabulary.
assert_contains "$MOUT" "member of a shared org board" "member => detected as a shared-org member"
assert_contains "$MOUT" "Uniform spine"  "member => applies the uniform spine"
assert_contains "$MOUT" "status: triage" "member => carries the status:* triage lane"
assert_contains "$MOUT" "status: staged" "member => carries the status:* staged lane"
assert_contains "$MOUT" "afk"            "member => carries the orthogonal afk facet"
assert_contains "$MOUT" "needs-info"     "member => carries the orthogonal needs-info facet"

# AC2 — the end-of-run board/CI prompt is skipped.
assert_contains "$MOUT" "SKIPPED"        "member => board/CI prompt is skipped"
assert_contains "$MOUT" "org"            "member => notes org plumbing already exists"

# AC3 — board automation stays decoupled and per-member, not templatized.
assert_contains "$MOUT" "DECOUPLED"      "member => board automation stays decoupled per-member"
assert_contains "$MOUT" "templatized"    "member => nothing is templatized across members"

# AC4 — never scaffolds the org itself.
assert_contains "$MOUT" "Not scaffolding the org" "member => never scaffolds the org itself"

# ---- AC1 override: a surveyed flat state is FORCED to kanban ----------------
FOUT="$(bash "$MEMBER" --root "$SANDBOX/member" --board-scope shared --surveyed-overlay flat 2>&1)"
assert_contains "$FOUT" "FORCED to 'kanban'" "member => surveyed flat overlay is forced to kanban"
assert_contains "$FOUT" "overrides a surveyed" "member => the override of the flat state is explicit"

FJSON="$(bash "$MEMBER" --root "$SANDBOX/member" --board-scope shared --surveyed-overlay flat --json 2>/dev/null)"
assert_contains "$FJSON" '"surveyed_overlay": "flat"'   "member json => records the surveyed flat overlay"
assert_contains "$FJSON" '"effective_overlay": "kanban"' "member json => effective overlay forced to kanban"
assert_contains "$FJSON" '"spine_override": true'        "member json => flags the spine override"

# ---- member seam --json verdict --------------------------------------------
MJSON="$(POCOCK_SHARED_ORGS="$ORG" bash "$MEMBER" --root "$SANDBOX/member" --json 2>/dev/null)"
if printf '%s\n' "$MJSON" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "member => json verdict is valid JSON"
else
  _bad "member => json verdict is not valid JSON"
fi
assert_contains "$MJSON" '"member": true'                     "member json => member=true"
assert_contains "$MJSON" '"board_scope": "shared"'            "member json => board_scope=shared"
assert_contains "$MJSON" '"uniform_spine": true'              "member json => uniform spine flagged"
assert_contains "$MJSON" '"board_ci_prompt": "skipped"'       "member json => board/CI prompt skipped"
assert_contains "$MJSON" '"board_automation": "decoupled-per-member"' "member json => decoupled per-member"
assert_contains "$MJSON" '"templatized": false'              "member json => not templatized"
assert_contains "$MJSON" '"per_repo_milestones": false'      "member json => no per-repo milestones (R8)"
assert_contains "$MJSON" '"scaffolds_org": false'            "member json => never scaffolds the org"
assert_contains "$MJSON" '"status: triage"'                  "member json => status vocab includes triage"

# When the survey already matches, spine_override is false (no phantom override).
NJSON="$(bash "$MEMBER" --root "$SANDBOX/member" --board-scope shared --surveyed-overlay kanban --json 2>/dev/null)"
assert_contains "$NJSON" '"spine_override": false' "member json => no override when survey already kanban"

# ---- own scope: member mode does not apply ---------------------------------
OOUT="$(bash "$MEMBER" --root "$SANDBOX/board" --board-scope own 2>&1)"
assert_eq 0 "$?" "own-scope member seam exits 0"
assert_contains "$OOUT" "not a member" "own => reports it is not a member"
assert_contains "$OOUT" "Member mode does not apply" "own => member mode does not apply"

OJSON="$(bash "$MEMBER" --root "$SANDBOX/board" --board-scope own --json 2>/dev/null)"
assert_contains "$OJSON" '"member": false' "own json => member=false"
if printf '%s\n' "$OJSON" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "own => json verdict is valid JSON"
else
  _bad "own => json verdict is not valid JSON"
fi

# ---- usage error on a bad board-scope --------------------------------------
bash "$MEMBER" --root "$SANDBOX/member" --board-scope bogus >/dev/null 2>&1
assert_eq 2 "$?" "invalid --board-scope exits 2"

# ---- detection is NOT duplicated: member seam reuses the emitter ------------
assert_contains "$(cat "$MEMBER")" "pocock-plan.sh" "member seam reuses the T1 emitter for board_scope detection"

# ---- the member seam mutates nothing ---------------------------------------
BEFORE="$(git -C "$SANDBOX/member" status --porcelain)"
POCOCK_SHARED_ORGS="$ORG" bash "$MEMBER" --root "$SANDBOX/member" >/dev/null 2>&1
AFTER="$(git -C "$SANDBOX/member" status --porcelain)"
assert_eq "$BEFORE" "$AFTER" "member verdict leaves the repo untouched"

finish "pocock-member"
