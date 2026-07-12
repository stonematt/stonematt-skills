#!/usr/bin/env bash
#
# pocock-preflight — the adopt-Pocock wrapper's wiring gate.
#
# Refuses to let downstream Pocock skills (e.g. /wayfinder) run on an unwired or
# provisional repo. The genesis breakage (#45): /wayfinder ran happily on an
# un-setup repo and *built a real map* — success was luck, not proof of wiring.
# "The map built successfully" is NOT proof of correct wiring, so this gate runs
# first and, on any miss, sends the human to reconcile config BEFORE auditing the
# wrapping layer — never audit-only (audit-only misses the config seam entirely).
#
# Detection is NOT duplicated here: the gate shells out to the pocock-plan
# emitter (the single detection authority) and reasons over the plan's `wiring`
# block + `stale_slugs`. This file is pure policy — no filesystem probing.
#
# Usage:
#   pocock-preflight.sh [--json] [--root DIR]
#
#   --json   emit a machine-readable verdict ({gate, misses}) instead of prose
#   --root   repo root to inspect (default: cwd)
#
# Exit: 0 when the gate PASSES (repo wired), 1 on any miss, 2 on usage error.

set -uo pipefail

JSON=0
ROOT="$PWD"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --root) ROOT="$2"; shift ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---- consume the emitter's plan (single detection authority) ---------------

PLAN="$(bash "$SELF_DIR/pocock-plan.sh" --dry-run --json --root "$ROOT" 2>/dev/null)" || {
  echo "pocock-preflight: could not obtain a plan from pocock-plan.sh" >&2
  exit 2
}

# Pull one wiring boolean off the plan. Detection already happened in the
# emitter; here we only read its verdict.
wiring_bool() { # key
  printf '%s\n' "$PLAN" | grep -oE "\"$1\": (true|false)" | grep -oE 'true|false' | head -1
}

# stale_slugs is empty iff the emitter rendered the inline "[]" form.
stale_clean() { case "$PLAN" in *'"stale_slugs": []'*) return 0;; *) return 1;; esac; }

# ---- evaluate the gate -----------------------------------------------------
# Each check maps 1:1 to an acceptance criterion (brief: Preflight wiring gate).

MISSES=()
[ "$(wiring_bool issue_tracker_present)"    = "true" ] || MISSES+=("issue-tracker.md missing")
[ "$(wiring_bool issue_tracker_reconciled)" = "true" ] || MISSES+=("issue-tracker.md provisional / not reconciled")
[ "$(wiring_bool triage_labels_present)"    = "true" ] || MISSES+=("triage-labels.md missing")
[ "$(wiring_bool domain_present)"           = "true" ] || MISSES+=("domain.md missing")
[ "$(wiring_bool roles_bound)"              = "true" ] || MISSES+=("canonical roles not bound")
stale_clean || MISSES+=("stale v1.0 slug references present")

# ---- render ----------------------------------------------------------------

if [ "$JSON" -eq 1 ]; then
  printf '{\n'
  if [ "${#MISSES[@]}" -eq 0 ]; then
    printf '  "gate": "pass",\n'
    printf '  "misses": []\n'
  else
    printf '  "gate": "fail",\n'
    printf '  "misses": [\n'
    i=1; n="${#MISSES[@]}"
    for m in "${MISSES[@]}"; do
      if [ "$i" -lt "$n" ]; then printf '    "%s",\n' "$m"; else printf '    "%s"\n' "$m"; fi
      i=$((i+1))
    done
    printf '  ]\n'
  fi
  printf '}\n'
else
  if [ "${#MISSES[@]}" -eq 0 ]; then
    printf 'GATE: PASS — repo is wired (config reconciled, roles bound, no stale v1.0 slugs).\n'
    printf 'Safe to run downstream Pocock skills.\n'
  else
    printf 'GATE: FAIL — repo is NOT wired for the current Pocock suite.\n'
    for m in "${MISSES[@]}"; do printf '  - %s\n' "$m"; done
    printf 'Do not run downstream Pocock skills (e.g. /wayfinder): a map that "builds\n'
    printf 'successfully" is NOT proof of correct wiring.\n'
    printf 'Next: reconcile config FIRST (setup-reconcile: issue-tracker / triage-labels /\n'
    printf 'domain), THEN audit the wrapping layer. Never audit-only.\n'
  fi
fi

[ "${#MISSES[@]}" -eq 0 ]
