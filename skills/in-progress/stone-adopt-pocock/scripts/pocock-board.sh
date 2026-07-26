#!/usr/bin/env bash
#
# pocock-board — the single Projects-v2 GraphQL helper the adopt-Pocock model calls.
#
# The board is an OPTIONAL flex point; the status:* label spine is the portable,
# complete default. When the model opts a repo into a real GitHub Projects v2
# board it calls this helper so it never freehands the hands-on GraphQL gotchas
# the #40 audit surfaced. Three deterministic operations, one per invocation:
#
#   status-field  Overwrite the UN-DELETABLE built-in Status single-select field's
#                 options IN PLACE. `deleteProjectV2Field` fails on a built-in
#                 field ("Only custom fields can be deleted"), so `updateProjectV2Field`
#                 REPLACES the whole option set instead. The returned field id +
#                 option ids are CAPTURED and emitted as JSON for the CI sync to
#                 consume (it maps each status:* label to an option id).
#
#   backfill      Put existing issues on the board (`addProjectV2ItemById`) and set
#                 each item's Status (`updateProjectV2ItemFieldValue`). The
#                 `issues`-triggered sync workflow runs only from the DEFAULT branch
#                 and is dormant until it lands there, so the initial backfill is
#                 done manually here. Reads `<issue_node_id> <option_id>` pairs on
#                 stdin.
#
#   labels        Idempotently create the canonical status:* lifecycle labels plus
#                 the orthogonal `afk` flag and `needs-info` facet. `Released` is
#                 label-less (the closed state), so it is intentionally absent.
#
# What this helper is NOT: detection, binding, board-scope (own|shared) branching,
# the audit sweep, and the project-sync / clean-status-on-close workflow files are
# the model's judgment or the skill/CI layer (slice #64) — none of it lives here.
#
# Usage:
#   pocock-board.sh status-field --field-id ID
#   pocock-board.sh backfill --project-id ID --field-id ID   # reads pairs on stdin
#   pocock-board.sh labels
#
#   status-field --field-id ID  node id of the built-in Status single-select field
#   backfill --project-id ID    node id of the Projects v2 board
#            --field-id ID       node id of the Status single-select field
#            (stdin)             one `<issue_node_id> <option_id>` pair per line;
#                                blank lines and `#` comments are ignored
#   labels                       no flags
#
# GraphQL variable binding: ALWAYS `-f`, NEVER `-F`.
#   Every variable here is `ID!` or `String!`. `gh api -F` type-INFERS its value,
#   so an all-digit option id (GitHub hands out plenty: `14416827`) goes over the
#   wire as an Int and the mutation is rejected against a String! variable. `-f`
#   always sends a string. Seen live on lithos-site 2026-07-20, where Triage and
#   Staged drew numeric ids and failed while the alphanumeric lanes passed.
#
# Determinism knobs (tests):
#   POCOCK_GH   the gh command (default `gh`) — every mutation + label edit
#
# Exit: 0 on success, 2 on usage error.

set -uo pipefail

GH="${POCOCK_GH:-gh}"

usage() { sed -n '2,53p' "${BASH_SOURCE[0]}"; }

# Parse a scalar out of a `gh api graphql` JSON response by dotted path.
# python3 is already a suite dependency.
json_get() { # path   (JSON on stdin)
  python3 -c '
import json,sys
d=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    if isinstance(d,dict): d=d.get(k)
    else: d=None
print(d if d is not None else "")
' "$1"
}

# ============================================================================
# status-field — overwrite the un-deletable built-in Status field in place
# ============================================================================
# A fresh Project ships a built-in Status single-select that CANNOT be deleted
# ("Only custom fields can be deleted"). `updateProjectV2Field` with
# `singleSelectOptions` REPLACES the whole option set, so we overwrite in place,
# then CAPTURE the returned field id + option ids for the CI sync to consume.
op_status_field() {
  local field_id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --field-id) field_id="$2"; shift ;;
      *) echo "status-field: unknown arg: $1" >&2; exit 2 ;;
    esac
    shift
  done
  [ -n "$field_id" ] || { echo "status-field: --field-id is required" >&2; exit 2; }

  local resp
  resp="$("$GH" api graphql -f query='
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
}' -f field="$field_id")" || {
    echo "status-field: updateProjectV2Field mutation failed" >&2
    exit 1
  }

  # Capture the field id + option ids and emit them as JSON for the CI sync.
  printf '%s' "$resp" | RESP="$resp" python3 -c '
import json,os,sys
d=json.loads(os.environ["RESP"])
f=(d.get("data",{}).get("updateProjectV2Field",{}) or {}).get("projectV2Field",{}) or {}
out={"status_field_id": f.get("id",""),
     "options": {o.get("name",""): o.get("id","") for o in f.get("options",[])}}
print(json.dumps(out, indent=2))
'
}

# ============================================================================
# backfill — put existing issues on the board and set their Status
# ============================================================================
# The project-sync workflow is dormant until it reaches the default branch, so
# existing issues are backfilled manually: add each to the board, then set its
# Status option. Reads `<issue_node_id> <option_id>` pairs on stdin.
op_backfill() {
  local project_id="" field_id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --project-id) project_id="$2"; shift ;;
      --field-id)   field_id="$2"; shift ;;
      *) echo "backfill: unknown arg: $1" >&2; exit 2 ;;
    esac
    shift
  done
  [ -n "$project_id" ] || { echo "backfill: --project-id is required" >&2; exit 2; }
  [ -n "$field_id" ]   || { echo "backfill: --field-id is required" >&2; exit 2; }

  local content_id option_id item_id resp n=0
  while read -r content_id option_id _; do
    case "$content_id" in ""|'#'*) continue ;; esac
    [ -n "$option_id" ] || { echo "backfill: missing option id for $content_id" >&2; exit 2; }

    # 1. Ensure the issue is on the board; capture the item id.
    resp="$("$GH" api graphql -f query='
mutation($project: ID!, $content: ID!) {
  addProjectV2ItemById(input: { projectId: $project, contentId: $content }) {
    item { id }
  }
}' -f project="$project_id" -f content="$content_id")" || {
      echo "backfill: addProjectV2ItemById failed for $content_id" >&2
      exit 1
    }
    item_id="$(printf '%s' "$resp" | json_get data.addProjectV2ItemById.item.id)"
    [ -n "$item_id" ] || { echo "backfill: no item id returned for $content_id" >&2; exit 1; }

    # 2. Set the item's Status to the mapped option id.
    "$GH" api graphql -f query='
mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $project
    itemId: $item
    fieldId: $field
    value: { singleSelectOptionId: $option }
  }) {
    projectV2Item { id }
  }
}' -f project="$project_id" -f item="$item_id" -f field="$field_id" -f option="$option_id" >/dev/null || {
      echo "backfill: updateProjectV2ItemFieldValue failed for $content_id" >&2
      exit 1
    }
    echo "backfill: $content_id -> item $item_id (option $option_id)"
    n=$((n+1))
  done
  echo "backfill: $n issue(s) placed on the board."
}

# ============================================================================
# labels — idempotently create the canonical status:* + afk + needs-info labels
# ============================================================================
# The status:* lane vocabulary + the orthogonal `afk` flag and `needs-info`
# facet. `Released` is label-less (it is the closed state), so it is absent.
# `gh label create --force` upserts, so re-running is a no-op.
op_labels() {
  # name|color|description
  local specs=(
    "status: triage|ededed|awaiting triage"
    "status: ready|0e8a16|ready to pick up"
    "status: wip|fbca04|in progress"
    "status: staged|5319e7|merged to dev, awaiting release"
    "status: blocked|d93f0b|blocked (side state)"
    "afk|1d76db|agent-ready (autonomous ok)"
    "needs-info|d4c5f9|missing information (orthogonal facet)"
  )
  local spec name color desc
  for spec in "${specs[@]}"; do
    name="${spec%%|*}"; spec="${spec#*|}"
    color="${spec%%|*}"; desc="${spec#*|}"
    if "$GH" label create "$name" --color "$color" --description "$desc" --force >/dev/null 2>&1; then
      echo "  label  $name"
    else
      echo "  label  $name  (gh label create failed — set by hand)"
    fi
  done
}

# ============================================================================
# main
# ============================================================================
[ $# -ge 1 ] || { usage >&2; exit 2; }

case "$1" in
  status-field) shift; op_status_field "$@" ;;
  backfill)     shift; op_backfill "$@" ;;
  labels)       shift; op_labels "$@" ;;
  -h|--help)    usage; exit 0 ;;
  *) echo "pocock-board: unknown command: $1" >&2; usage >&2; exit 2 ;;
esac
