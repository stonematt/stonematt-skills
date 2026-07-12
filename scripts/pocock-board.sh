#!/usr/bin/env bash
#
# pocock-board — the adopt-Pocock wrapper's OPTIONAL board/CI projection.
#
# The portable default is LABEL-ONLY: the `status:*` label vocabulary + state
# machine port everywhere, and the config is valid and complete without any of
# the CI machinery this script emits. The Project v2 board + `project-sync.yml` +
# `clean-status-on-close.yml` are a *flex point*, never a requirement. This script
# is the end-of-run prompt's yes-branch: it projects the label spine onto a
# GitHub Projects v2 board and wires the CI that keeps the board in sync.
#
# It handles the hands-on GitHub Projects gotchas the #40 audit surfaced:
#   1. The built-in Status single-select field is UN-DELETABLE. Its options are
#      overwritten in place via raw `gh api graphql updateProjectV2Field` (the
#      mutation replaces the whole option set); the field id + option ids are
#      then captured for the CI sync.
#   2. Project v2 mutations need a PAT with `project` write — `GITHUB_TOKEN`
#      cannot write user-owned Projects v2. This script emits a precise
#      `PROJECT_TOKEN` checklist and STOPS for the human to provision it.
#   3. `issues`-triggered workflows run from the DEFAULT branch, so under
#      feature->dev->main they stay DORMANT until the first dev->main release PR
#      lands them on `main`. Backfill of existing issues is therefore MANUAL
#      GraphQL (`addProjectV2ItemById` + `updateProjectV2ItemFieldValue`), not a
#      lean on the fresh (dormant) workflow.
#   4. An open issue with a live branch but no `status:*` label is invisible to
#      the board. `--audit-sweep` reconciles a lane from branch/PR state.
#
# Detection is NOT duplicated here: like the preflight gate (#54) this consumes
# the pocock-plan emitter (the single detection authority) for the `board_scope`
# slot. Board scope is a detect-then-confirm contextual slot (brief R6); the
# human confirms/overrides the proposed value with `--board-scope`.
#
# On a MEMBER repo of an existing org board (`--board-scope shared`), the org
# plumbing already exists, so the end-of-run prompt is the opt-out seam and is
# SKIPPED — this script emits the skip note and does nothing else. The wrapper
# never scaffolds the org itself.
#
# Usage:
#   pocock-board.sh [--root DIR] [--plan FILE] [--board-scope own|shared]
#                   [--project-title T] [--json] [--write] [--audit-sweep]
#
#   --root DIR         repo root (default: cwd)
#   --plan FILE        pre-emitted plan JSON; else runs pocock-plan.sh
#   --board-scope S    confirm/override the plan's board_scope slot (own|shared)
#   --project-title T  Project v2 board title to reference (default: repo name)
#   --json             emit a machine-readable projection verdict
#   --write            actually write the .github/workflows/*.yml files
#                      (default: emit them to stdout, mutate nothing)
#   --audit-sweep      reconcile open issues lacking a status:* label from
#                      branch/PR state (uses `gh`; override via POCOCK_GH)
#
# Determinism knobs (tests):
#   POCOCK_GH   the gh command (default `gh`) — audit sweep + label edits
#
# Exit: 0 on success (including the member-repo skip), 2 on usage error.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$PWD"
PLAN_FILE=""
BOARD_SCOPE=""
PROJECT_TITLE=""
JSON=0
WRITE=0
AUDIT_SWEEP=0
GH="${POCOCK_GH:-gh}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root)          ROOT="$2"; shift ;;
    --plan)          PLAN_FILE="$2"; shift ;;
    --board-scope)   BOARD_SCOPE="$2"; shift ;;
    --project-title) PROJECT_TITLE="$2"; shift ;;
    --json)          JSON=1 ;;
    --write)         WRITE=1 ;;
    --audit-sweep)   AUDIT_SWEEP=1 ;;
    -h|--help)       sed -n '2,58p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---- consume the emitter's plan (single detection authority) ---------------

if [ -n "$PLAN_FILE" ]; then
  PLAN_JSON="$(cat "$PLAN_FILE")"
else
  PLAN_JSON="$(bash "$SELF_DIR/pocock-plan.sh" --dry-run --json --root "$ROOT" 2>/dev/null)" || {
    echo "pocock-board: could not obtain a plan from pocock-plan.sh" >&2
    exit 2
  }
fi

# Read a scalar slot off the plan's proposed_slots block (jq-free; python3 is
# already a suite dependency — see scripts/pocock-apply.sh).
plan_slot() { # key
  printf '%s' "$PLAN_JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(d.get("proposed_slots",{}).get(sys.argv[1],""))
' "$1"
}

# Board scope: the plan proposes it; the human confirms/overrides (detect-then-
# confirm, brief R6). An explicit --board-scope wins.
if [ -z "$BOARD_SCOPE" ]; then
  BOARD_SCOPE="$(plan_slot board_scope)"
  [ -n "$BOARD_SCOPE" ] || BOARD_SCOPE="own"
fi
case "$BOARD_SCOPE" in
  own|shared) ;;
  *) echo "pocock-board: --board-scope must be own|shared (got '$BOARD_SCOPE')" >&2; exit 2 ;;
esac

[ -n "$PROJECT_TITLE" ] || PROJECT_TITLE="$(basename "$ROOT")"

WORKFLOW_DIR=".github/workflows"
WF_SYNC="$WORKFLOW_DIR/project-sync.yml"
WF_CLEAN="$WORKFLOW_DIR/clean-status-on-close.yml"

# ============================================================================
# audit sweep — reconcile open issues lacking a status:* label
# ============================================================================
# An open issue with a live branch/PR but no status:* label is invisible to the
# board. Reconcile a lane from branch/PR state:
#   merged PR  -> status: staged   (merged to dev)
#   open PR    -> status: wip
#   live branch (feat/<n>-… / fix/<n>-… / any *<n>-*) but no PR -> status: wip
#   nothing    -> status: triage
# Issues already carrying a status:* label are left alone (already on a lane).
run_audit_sweep() {
  local issues prs branches
  issues="$("$GH" issue list --state open --json number,title,labels 2>/dev/null)" || issues="[]"
  prs="$("$GH" pr list --state all --json number,state,headRefName,title,body 2>/dev/null)" || prs="[]"
  # Live local branches carry a `<n>-` slug segment for their issue.
  branches="$(git -C "$ROOT" branch --format='%(refname:short)' 2>/dev/null | tr '\n' ' ')"

  local plan
  plan="$(ISSUES="$issues" PRS="$prs" BRANCHES="$branches" python3 <<'PY'
import json, os, re

issues = json.loads(os.environ.get("ISSUES") or "[]")
prs    = json.loads(os.environ.get("PRS") or "[]")
branches = (os.environ.get("BRANCHES") or "").split()

def issue_refs(pr):
    text = f"{pr.get('title','')} {pr.get('body','')} {pr.get('headRefName','')}"
    return set(int(n) for n in re.findall(r'#?(\d+)', text))

# Map issue number -> best PR state (merged beats open beats closed).
rank = {"MERGED": 3, "OPEN": 2, "CLOSED": 1}
pr_state = {}
for pr in prs:
    st = (pr.get("state") or "").upper()
    for n in issue_refs(pr):
        if rank.get(st, 0) > rank.get(pr_state.get(n, ""), 0):
            pr_state[n] = st

branch_issue = set()
for b in branches:
    m = re.search(r'(?:^|/)(\d+)-', b)
    if m:
        branch_issue.add(int(m.group(1)))

def has_status(issue):
    return any((l.get("name","").startswith("status:")) for l in issue.get("labels", []))

for issue in issues:
    n = issue.get("number")
    if has_status(issue):
        continue
    st = pr_state.get(n)
    if st == "MERGED":
        lane = "status: staged"
    elif st == "OPEN":
        lane = "status: wip"
    elif n in branch_issue:
        lane = "status: wip"
    else:
        lane = "status: triage"
    print(f"{n}\t{lane}")
PY
)"

  if [ -z "$plan" ]; then
    echo "pocock-board audit-sweep: every open issue already carries a status:* label — nothing to reconcile."
    return 0
  fi

  echo "pocock-board audit-sweep: reconciling open issues with no status:* label from branch/PR state:"
  local n lane
  while IFS=$'\t' read -r n lane; do
    [ -n "$n" ] || continue
    if "$GH" issue edit "$n" --add-label "$lane" >/dev/null 2>&1; then
      echo "  #$n -> $lane"
    else
      echo "  #$n -> $lane  (gh issue edit failed — set by hand)"
    fi
  done <<< "$plan"
}

# ============================================================================
# workflow YAML — the CI that keeps the board in sync with status:* labels
# ============================================================================
emit_project_sync_yml() {
  cat <<'YAML'
# project-sync — mirror status:* labels onto the Projects v2 board Status field.
#
# DORMANCY: `issues`-triggered workflows run from the DEFAULT branch. Under
# feature->dev->main this file is dormant until the first dev->main release PR
# lands it on `main`. Existing issues must be backfilled with MANUAL GraphQL
# (see the pocock-board backfill block), not left to this (dormant) workflow.
#
# GITHUB_TOKEN CANNOT write user-owned Projects v2 — a PAT with `project` write
# is required. Provision it as the PROJECT_TOKEN secret (see the checklist).
name: project-sync
on:
  issues:
    types: [opened, reopened, labeled, unlabeled, closed]
  pull_request:
    types: [opened, closed]
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Add item to board + set Status from the status:* label
        env:
          GH_TOKEN: ${{ secrets.PROJECT_TOKEN }}
          PROJECT_ID: ${{ vars.POCOCK_PROJECT_ID }}
          STATUS_FIELD_ID: ${{ vars.POCOCK_STATUS_FIELD_ID }}
        run: |
          # 1. addProjectV2ItemById to ensure the issue is on the board.
          # 2. updateProjectV2ItemFieldValue to set Status from the status:* label,
          #    using the option ids captured by `pocock-board.sh` (the gotcha step).
          echo "sync: map status:* label -> Status option id (see captured ids)"
YAML
}

emit_clean_status_yml() {
  cat <<'YAML'
# clean-status-on-close — project a closed issue to the label-less Released lane.
#
# `Released` is label-less (nitimini invariant): where a board exists,
# Status=Released is just the projection of the issue's closed state. On close,
# set the board Status to Released; there is no `status: released` label.
name: clean-status-on-close
on:
  issues:
    types: [closed]
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Set board Status = Released (projection of closed)
        env:
          GH_TOKEN: ${{ secrets.PROJECT_TOKEN }}
          PROJECT_ID: ${{ vars.POCOCK_PROJECT_ID }}
          STATUS_FIELD_ID: ${{ vars.POCOCK_STATUS_FIELD_ID }}
        run: |
          echo "release: updateProjectV2ItemFieldValue Status -> Released option id"
YAML
}

# ============================================================================
# projection prose — the gotchas the human must action
# ============================================================================
emit_status_field_mutation() {
  cat <<'GQL'
# --- Overwrite the UN-DELETABLE built-in Status field's options in place -------
# A fresh Project ships a built-in Status single-select that is un-deletable:
#   `deleteProjectV2Field` -> "Only custom fields can be deleted".
# So overwrite its options in place — `updateProjectV2Field` with
# `singleSelectOptions` REPLACES the whole option set. Then CAPTURE the returned
# field id + option ids: the CI sync maps each status:* label to an option id.
gh api graphql -f query='
mutation($field: ID!) {
  updateProjectV2Field(input: {
    fieldId: $field
    singleSelectOptions: [
      { name: "Triage",   color: GRAY,   description: "status: triage" },
      { name: "Ready",    color: BLUE,   description: "status: ready (+afk = agent-ready)" },
      { name: "WIP",      color: YELLOW, description: "status: wip" },
      { name: "Staged",   color: PURPLE, description: "status: staged (merged to dev)" },
      { name: "Blocked",  color: RED,    description: "status: blocked (side state)" },
      { name: "Released", color: GREEN,  description: "closed projection (label-less)" }
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        options { id name }
      }
    }
  }
}' -F field="$STATUS_FIELD_ID"
# ^ Record the printed field id + option ids as POCOCK_STATUS_FIELD_ID and the
#   per-lane option ids the two workflows above consume.
GQL
}

emit_project_token_checklist() {
  cat <<'EOF'
# --- PROJECT_TOKEN — irreducible human secret step (STOP here) -----------------
# Project v2 mutations need a PAT with `project` write; GITHUB_TOKEN cannot write
# user-owned Projects v2. This script writes the YAML but STOPS: provision the
# credential yourself, then re-run the capture + backfill.
#
#   [ ] Create a fine-grained PAT (hardened variant): github.com/settings/tokens
#   [ ] Resource owner = the board owner (user or org); scope to this repo
#   [ ] Permission: "Projects" = Read and write
#   [ ] (org board) also grant the org's Projects read/write
#   [ ] Save it as the repo secret PROJECT_TOKEN:
#         gh secret set PROJECT_TOKEN --body '<pat>'
#   [ ] Set the board ids as repo variables the workflows read:
#         gh variable set POCOCK_PROJECT_ID --body '<project node id>'
#         gh variable set POCOCK_STATUS_FIELD_ID --body '<status field id>'
#
# Do NOT proceed to the board mutations until PROJECT_TOKEN exists.
EOF
}

emit_backfill_block() {
  cat <<'EOF'
# --- Backfill existing issues — MANUAL GraphQL (workflow is dormant) -----------
# The project-sync workflow runs only from the DEFAULT branch, so under
# feature->dev->main it is DORMANT until the first dev->main release PR lands it
# on `main`. Do NOT wait for it to backfill — sweep existing issues by hand:
#
#   for each open issue node id:
#     gh api graphql -f query='mutation($p:ID!,$c:ID!){
#       addProjectV2ItemById(input:{projectId:$p, contentId:$c}){ item { id } } }' \
#       -F p="$PROJECT_ID" -F c="$ISSUE_NODE_ID"
#     gh api graphql -f query='mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){
#       updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,
#         value:{singleSelectOptionId:$o}}){ projectV2Item { id } } }' \
#       -F p="$PROJECT_ID" -F i="$ITEM_ID" -F f="$STATUS_FIELD_ID" -F o="$OPTION_ID"
#
# Run `pocock-board.sh --audit-sweep` FIRST so every open issue carries a
# status:* label to project onto an option id.
EOF
}

# ============================================================================
# main
# ============================================================================

# The audit sweep is an independent verb — run it and stop (it reconciles labels,
# it does not emit the projection).
if [ "$AUDIT_SWEEP" -eq 1 ]; then
  run_audit_sweep
  exit 0
fi

# Member repo of an existing org board: the prompt is the OPT-OUT seam and is
# skipped — org plumbing already exists; the label spine is already the complete,
# portable default. The wrapper never scaffolds the org itself.
if [ "$BOARD_SCOPE" = "shared" ]; then
  if [ "$JSON" -eq 1 ]; then
    printf '{\n'
    printf '  "board_scope": "shared",\n'
    printf '  "prompt": "skip-member-repo",\n'
    printf '  "label_only_complete": true\n'
    printf '}\n'
  else
    echo "pocock-board: member repo of an existing org board (board_scope=shared)."
    echo "The end-of-run board/CI prompt is the opt-out seam and is SKIPPED here —"
    echo "the org's board + project-sync plumbing already exists per-org. The"
    echo "status:* label spine is the portable default and is already complete;"
    echo "label-only is valid without any per-repo board wiring. Not scaffolding"
    echo "the org itself (out of scope)."
  fi
  exit 0
fi

# board_scope=own: offer the full board + CI projection.
if [ "$JSON" -eq 1 ]; then
  printf '{\n'
  printf '  "board_scope": "own",\n'
  printf '  "prompt": "offer",\n'
  printf '  "project_title": "%s",\n' "$PROJECT_TITLE"
  printf '  "label_only_complete": true,\n'
  printf '  "status_field_mutation": "updateProjectV2Field",\n'
  printf '  "workflows": [\n'
  printf '    "%s",\n' "$WF_SYNC"
  printf '    "%s"\n'  "$WF_CLEAN"
  printf '  ],\n'
  printf '  "project_token_required": true,\n'
  printf '  "ci_dormant_until_default_branch": true,\n'
  printf '  "backfill": "manual-graphql",\n'
  printf '  "audit_sweep_available": true\n'
  printf '}\n'
  exit 0
fi

echo "pocock-board: OPTIONAL board/CI projection (board_scope=own)."
echo "Portable default is LABEL-ONLY — the status:* spine is already valid and"
echo "complete without any of the below. This is the end-of-run prompt's yes-branch."
echo

if [ "$WRITE" -eq 1 ]; then
  mkdir -p "$ROOT/$WORKFLOW_DIR"
  if [ -f "$ROOT/$WF_SYNC" ]; then echo "  skip   $WF_SYNC (exists)"; else
    emit_project_sync_yml > "$ROOT/$WF_SYNC"; echo "  write  $WF_SYNC"; fi
  if [ -f "$ROOT/$WF_CLEAN" ]; then echo "  skip   $WF_CLEAN (exists)"; else
    emit_clean_status_yml > "$ROOT/$WF_CLEAN"; echo "  write  $WF_CLEAN"; fi
else
  echo "==== $WF_SYNC ===="
  emit_project_sync_yml
  echo
  echo "==== $WF_CLEAN ===="
  emit_clean_status_yml
fi

echo
emit_status_field_mutation
echo
emit_project_token_checklist
echo
emit_backfill_block
echo
echo "Next: (1) provision PROJECT_TOKEN (STOP for the human), (2) run the Status"
echo "field mutation + capture ids, (3) pocock-board.sh --audit-sweep, (4) backfill."
