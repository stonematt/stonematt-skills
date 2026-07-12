#!/usr/bin/env bash
# Board/CI projection (#56): the adopt-Pocock wrapper's OPTIONAL, prompted
# board/CI flex point. Label-only is the portable default; this projects the
# status:* spine onto a Projects v2 board and emits the hands-on GitHub gotchas
# (un-deletable Status field, PROJECT_TOKEN stop, CI dormancy + manual backfill,
# audit sweep). On a shared-org member repo the prompt is the opt-out seam.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_fixtures "$SANDBOX"

BOARD="$SCRIPTS_DIR/pocock-board.sh"
REPO="$SANDBOX/board"

run_own() { bash "$BOARD" --root "$REPO" "$@" 2>&1; }

# ---- own scope: full projection emitted ------------------------------------
# board_scope defaults to the plan's "own" slot — no override needed.
OUT="$(run_own)"
RC=$?
assert_eq 0 "$RC" "own-scope projection exits 0"

# Label-only is valid and complete WITHOUT any of this (AC1).
assert_contains "$OUT" "LABEL-ONLY" "own => states label-only is the portable default"
assert_contains "$OUT" "valid and" "own => label-only is valid and complete without the board"

# Un-deletable Status field overwritten in place via raw graphql (AC2).
assert_contains "$OUT" "updateProjectV2Field" "own => raw graphql updateProjectV2Field"
assert_contains "$OUT" "singleSelectOptions"  "own => replaces the whole option set"
assert_contains "$OUT" "un-deletable"         "own => notes the built-in Status field is un-deletable"
assert_contains "$OUT" "Only custom fields can be deleted" "own => cites the delete error"
assert_contains "$OUT" "CAPTURE"              "own => captures field id + option ids for CI"
assert_contains "$OUT" "options { id name }"  "own => graphql returns option ids to capture"

# PROJECT_TOKEN checklist emitted; skill STOPS for the human (AC3).
assert_contains "$OUT" "PROJECT_TOKEN"  "own => emits PROJECT_TOKEN checklist"
assert_contains "$OUT" "STOP"           "own => stops for the human to provision the credential"
assert_contains "$OUT" "GITHUB_TOKEN cannot write" "own => explains GITHUB_TOKEN can't write Projects v2"
assert_contains "$OUT" "gh secret set PROJECT_TOKEN" "own => shows how to set the secret"

# CI dormancy warning + manual GraphQL backfill (AC4).
assert_contains "$OUT" "DORMANT"                    "own => warns issues-triggered CI is dormant"
assert_contains "$OUT" "DEFAULT branch"             "own => dormant until the default branch"
assert_contains "$OUT" "addProjectV2ItemById"       "own => backfill via addProjectV2ItemById"
assert_contains "$OUT" "updateProjectV2ItemFieldValue" "own => backfill sets field values manually"
assert_contains "$OUT" "MANUAL"                     "own => backfill is manual, not the dormant workflow"

# Both workflow files named.
assert_contains "$OUT" ".github/workflows/project-sync.yml"          "own => names project-sync.yml"
assert_contains "$OUT" ".github/workflows/clean-status-on-close.yml" "own => names clean-status-on-close.yml"

# ---- own scope --json ------------------------------------------------------
JOUT="$(bash "$BOARD" --root "$REPO" --json 2>/dev/null)"
if printf '%s\n' "$JOUT" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "own => json verdict is valid JSON"
else
  _bad "own => json verdict is not valid JSON"
fi
assert_contains "$JOUT" '"prompt": "offer"'          "own => json prompt=offer"
assert_contains "$JOUT" '"board_scope": "own"'       "own => json board_scope=own"
assert_contains "$JOUT" '"label_only_complete": true' "own => json marks label-only complete"
assert_contains "$JOUT" '"project_token_required": true' "own => json flags PROJECT_TOKEN required"
assert_contains "$JOUT" '"ci_dormant_until_default_branch": true' "own => json flags CI dormancy"

# ---- shared scope: prompt is the opt-out seam, SKIPPED ---------------------
# On a member repo of an existing org board the org plumbing already exists.
SOUT="$(bash "$BOARD" --root "$REPO" --board-scope shared 2>&1)"
assert_eq 0 "$?" "shared-scope skip exits 0"
assert_contains "$SOUT" "SKIPPED"        "shared => board/CI prompt is skipped (opt-out seam)"
assert_contains "$SOUT" "org"            "shared => notes org plumbing already exists"
assert_contains "$SOUT" "label-only is valid" "shared => label-only still valid/complete"
assert_contains "$SOUT" "Not scaffolding" "shared => never scaffolds the org itself"

SJSON="$(bash "$BOARD" --root "$REPO" --board-scope shared --json 2>/dev/null)"
assert_contains "$SJSON" '"prompt": "skip-member-repo"' "shared => json prompt=skip-member-repo"
if printf '%s\n' "$SJSON" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "shared => json verdict is valid JSON"
else
  _bad "shared => json verdict is not valid JSON"
fi

# ---- --write: actually writes the workflow files, idempotently -------------
bash "$BOARD" --root "$REPO" --write >/dev/null 2>&1
assert_file "$REPO/.github/workflows/project-sync.yml"          "--write creates project-sync.yml"
assert_file "$REPO/.github/workflows/clean-status-on-close.yml" "--write creates clean-status-on-close.yml"
SYNC="$(cat "$REPO/.github/workflows/project-sync.yml")"
assert_contains "$SYNC" "secrets.PROJECT_TOKEN" "workflow reads the PROJECT_TOKEN secret"
assert_contains "$SYNC" "on:" "workflow is a valid-looking GH Actions file"
# Idempotent: a second --write skips the existing files, does not clobber.
W2="$(bash "$BOARD" --root "$REPO" --write 2>&1)"
assert_contains "$W2" "skip   .github/workflows/project-sync.yml (exists)" "--write is idempotent (skips existing)"

# ---- audit sweep: reconcile open issues lacking status:* from branch/PR -----
chmod +x "$TESTS_DIR/gh-board-shim"
ISS="$SANDBOX/issues.json"; PRS="$SANDBOX/prs.json"; EDITS="$SANDBOX/edits.log"
cat > "$ISS" <<'EOF'
[
  {"number":10,"title":"already on a lane","labels":[{"name":"status: wip"}]},
  {"number":11,"title":"has merged PR","labels":[]},
  {"number":12,"title":"has open PR","labels":[]},
  {"number":13,"title":"live branch, no PR","labels":[{"name":"afk"}]},
  {"number":14,"title":"no branch, no PR","labels":[]}
]
EOF
cat > "$PRS" <<'EOF'
[
  {"number":91,"state":"MERGED","headRefName":"feat/11-x","title":"do 11","body":"closes #11"},
  {"number":92,"state":"OPEN","headRefName":"feat/12-y","title":"do 12","body":"part of #12"}
]
EOF
: > "$EDITS"

POCOCK_GH="$TESTS_DIR/gh-board-shim" \
  GH_ISSUE_JSON="$ISS" GH_PR_JSON="$PRS" GH_EDIT_LOG="$EDITS" \
  bash "$BOARD" --root "$REPO" --audit-sweep >/dev/null 2>&1

EDITLOG="$(cat "$EDITS")"
# #10 already carries a status:* label => left alone (not in the edit log).
assert_not_contains "$EDITLOG" "10	" "audit => issue already on a lane is left alone"
# merged PR => staged; open PR => wip; live branch (feat/13-…) => wip; none => triage.
assert_contains "$EDITLOG" "11	status: staged" "audit => merged PR reconciles to staged"
assert_contains "$EDITLOG" "12	status: wip"    "audit => open PR reconciles to wip"
assert_contains "$EDITLOG" "13	status: wip"    "audit => live branch (no PR) reconciles to wip"
assert_contains "$EDITLOG" "14	status: triage" "audit => no branch/PR reconciles to triage"

# ---- detection is NOT duplicated: board reuses the emitter ------------------
assert_contains "$(cat "$BOARD")" "pocock-plan.sh" "board reuses the T1 emitter for board_scope detection"

finish "pocock-board"
