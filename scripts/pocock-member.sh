#!/usr/bin/env bash
#
# pocock-member — the adopt-Pocock wrapper's MULTI-REPO MEMBER mode (#58).
#
# On a member of a shared org board the org plumbing already exists, so the
# wrapper does LESS, not more: it applies the same uniform spine every member
# carries and skips the per-repo board-wiring prompt. This seam computes the
# member verdict — the parts that differ from the own-scope flow.
#
# The load-bearing rule (brief, "Multi-repo"): a member gets the UNIFORM SPINE
# incl. the SAME `status:*` vocabulary — consistency across the fleet is the
# whole point. That uniformity OVERRIDES a surveyed "flat, no kanban" state: on
# a member the lifecycle overlay is forced to `kanban` even if the survey (or a
# human correction) proposed `flat`. A member repo is on an org board; a flat,
# board-less lane model would break fleet consistency.
#
# Four invariants this seam enforces (the ticket's acceptance criteria):
#   1. Shared-org member detected -> uniform spine + same status:* vocab, forced
#      over a surveyed flat state.
#   2. The end-of-run board/CI prompt is SKIPPED (the opt-out seam pocock-board
#      already implements for board_scope=shared).
#   3. Board/project automation stays DECOUPLED and per-member — never
#      templatized across members (each member wires its own project-sync to the
#      shared board; the wrapper does not clone a copy).
#   4. The wrapper NEVER scaffolds the org itself (governance + `.github` repos
#      are a human, one-time act — out of scope).
#
# Detection is NOT duplicated here: like the preflight (#54) and board (#56)
# seams this consumes the pocock-plan emitter (the single detection authority)
# for the `board_scope` slot. Board scope is a detect-then-confirm slot (R6);
# the human confirms/overrides the proposed value with `--board-scope`.
#
# Usage:
#   pocock-member.sh [--root DIR] [--plan FILE] [--board-scope own|shared]
#                    [--surveyed-overlay kanban|flat|identity] [--json]
#
#   --root DIR            repo root (default: cwd)
#   --plan FILE           pre-emitted plan JSON; else runs pocock-plan.sh
#   --board-scope S       confirm/override the plan's board_scope slot (own|shared)
#   --surveyed-overlay O  the surveyed/confirmed lifecycle overlay to reconcile
#                         against the uniform spine (default: the plan's proposal).
#                         On a member a `flat`/`identity` value is OVERRIDDEN to
#                         `kanban` and the override is reported.
#   --json                emit a machine-readable member verdict
#
# Exit: 0 on success (member verdict, or the own-scope not-applicable note),
#       2 on usage error.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$PWD"
PLAN_FILE=""
BOARD_SCOPE=""
SURVEYED_OVERLAY=""
JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)             ROOT="$2"; shift ;;
    --plan)             PLAN_FILE="$2"; shift ;;
    --board-scope)      BOARD_SCOPE="$2"; shift ;;
    --surveyed-overlay) SURVEYED_OVERLAY="$2"; shift ;;
    --json)             JSON=1 ;;
    -h|--help)          sed -n '2,49p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# The uniform spine every member carries — the SAME status:* lifecycle + the
# orthogonal facets an own-scope repo gets. Consistency across the fleet is the
# point; this list is identical to the plan/apply canonical set.
CANON_LABELS=(
  "status: triage"
  "status: ready"
  "status: wip"
  "status: staged"
  "status: blocked"
  "afk"
  "needs-info"
)

# ---- consume the emitter's plan (single detection authority) ---------------

if [ -n "$PLAN_FILE" ]; then
  PLAN_JSON="$(cat "$PLAN_FILE")"
else
  PLAN_JSON="$(bash "$SELF_DIR/pocock-plan.sh" --dry-run --json --root "$ROOT" 2>/dev/null)" || {
    echo "pocock-member: could not obtain a plan from pocock-plan.sh" >&2
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
# confirm, R6). An explicit --board-scope wins.
if [ -z "$BOARD_SCOPE" ]; then
  BOARD_SCOPE="$(plan_slot board_scope)"
  [ -n "$BOARD_SCOPE" ] || BOARD_SCOPE="own"
fi
case "$BOARD_SCOPE" in
  own|shared) ;;
  *) echo "pocock-member: --board-scope must be own|shared (got '$BOARD_SCOPE')" >&2; exit 2 ;;
esac

# The surveyed/confirmed overlay we reconcile against the uniform spine.
if [ -z "$SURVEYED_OVERLAY" ]; then
  SURVEYED_OVERLAY="$(plan_slot lifecycle_overlay)"
  [ -n "$SURVEYED_OVERLAY" ] || SURVEYED_OVERLAY="kanban"
fi

# ============================================================================
# not a member — own scope: member mode does not apply
# ============================================================================
if [ "$BOARD_SCOPE" != "shared" ]; then
  if [ "$JSON" -eq 1 ]; then
    printf '{\n'
    printf '  "board_scope": "own",\n'
    printf '  "member": false,\n'
    printf '  "note": "own-scope repo — run the standard greenfield + board projection flow"\n'
    printf '}\n'
  else
    echo "pocock-member: board_scope=own — this is not a member of a shared org board."
    echo "Member mode does not apply; run the standard greenfield apply + the"
    echo "(prompted) board/CI projection (pocock-board.sh) instead."
  fi
  exit 0
fi

# ============================================================================
# member of a shared org board — the uniform spine, forced; the prompt skipped
# ============================================================================
# The uniform status:* spine is FORCED to kanban regardless of the survey — a
# member's lanes must match the fleet (AC1). Record whether that overrode a
# surveyed flat/identity state so the override is visible, not silent.
EFFECTIVE_OVERLAY="kanban"
if [ "$SURVEYED_OVERLAY" != "$EFFECTIVE_OVERLAY" ]; then
  SPINE_OVERRIDE="true"
else
  SPINE_OVERRIDE="false"
fi

if [ "$JSON" -eq 1 ]; then
  printf '{\n'
  printf '  "board_scope": "shared",\n'
  printf '  "member": true,\n'
  # AC1 — uniform spine + same status:* vocab, forced over a surveyed flat state.
  printf '  "surveyed_overlay": "%s",\n' "$SURVEYED_OVERLAY"
  printf '  "effective_overlay": "%s",\n' "$EFFECTIVE_OVERLAY"
  printf '  "spine_override": %s,\n' "$SPINE_OVERRIDE"
  printf '  "uniform_spine": true,\n'
  printf '  "status_vocabulary": [\n'
  local_i=1
  n="${#CANON_LABELS[@]}"
  for l in "${CANON_LABELS[@]}"; do
    if [ "$local_i" -lt "$n" ]; then printf '    "%s",\n' "$l"; else printf '    "%s"\n' "$l"; fi
    local_i=$((local_i+1))
  done
  printf '  ],\n'
  # AC2 — the end-of-run board/CI prompt is skipped on a member.
  printf '  "board_ci_prompt": "skipped",\n'
  # AC3 — board/project automation stays decoupled and per-member.
  printf '  "board_automation": "decoupled-per-member",\n'
  printf '  "templatized": false,\n'
  printf '  "per_repo_milestones": false,\n'
  # AC4 — the wrapper never scaffolds the org itself.
  printf '  "scaffolds_org": false\n'
  printf '}\n'
  exit 0
fi

echo "pocock-member: member of a shared org board (board_scope=shared)."
echo
echo "Uniform spine — applying the SAME status:* vocabulary every member carries"
echo "(consistency across the fleet is the point):"
printf '  %s\n' "${CANON_LABELS[@]}"
echo
if [ "$SPINE_OVERRIDE" = "true" ]; then
  echo "Override: surveyed overlay was '$SURVEYED_OVERLAY' — FORCED to 'kanban'."
  echo "A member repo sits on the org board; the uniform status:* spine"
  echo "overrides a surveyed flat/identity state so every member stays consistent."
else
  echo "Lifecycle overlay: kanban (uniform status:* spine) — matches the survey."
fi
echo
echo "Board/CI prompt: SKIPPED. The org's board + project-sync plumbing already"
echo "exists per-org; this is the opt-out seam (see pocock-board.sh --board-scope"
echo "shared). The label spine is the portable default and is already complete."
echo
echo "Board/project automation stays DECOUPLED and per-member — each member wires"
echo "its own project-sync to the shared board; nothing is templatized/cloned"
echo "across members."
echo
echo "Not scaffolding the org itself — standing up the org's governance + .github"
echo "mechanics repos is a human, one-time act (out of scope)."
