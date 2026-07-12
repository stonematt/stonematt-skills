#!/usr/bin/env bash
#
# pocock-plan — the adopt-Pocock wrapper's deterministic plan-emitter seam.
#
# Given a repo, inspect its state and emit a PLAN describing what an adopt run
# *would* do — mutating nothing. The plan is the tested seam: the wrapper skill
# reasons over this JSON before it writes a single file or creates a label.
#
# Detection walks two orthogonal axes (see docs/briefs/adopt-pocock-wrapper.md):
#   substrate  — tracker-backed (origin remote present) vs trackerless-local
#   freshness  — greenfield (no config) / migrant (old slugs or stamp drift) /
#                current (config present, stamp == installed)
#
# Usage:
#   pocock-plan.sh --dry-run --json [--root DIR]
#
#   --dry-run   inspect + emit plan only; never mutate (currently the ONLY mode)
#   --json      emit the machine-readable plan JSON (pretty, deterministic)
#   --root      repo root to inspect (default: cwd)
#
# The seam is offline and side-effect-free: no `gh`, no network, no writes.
# `POCOCK_INSTALLED_VERSION` overrides the installed-suite version (drift math).

set -uo pipefail

DRY_RUN=0
JSON=0
ROOT="$PWD"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --json)    JSON=1 ;;
    --root)    ROOT="$2"; shift ;;
    -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# The seam only knows how to plan (dry-run). A mutating apply is a later ticket.
if [ "$DRY_RUN" -ne 1 ]; then
  echo "pocock-plan: only --dry-run is supported (the plan seam mutates nothing)" >&2
  exit 2
fi

# Canonical spine — fixed inputs the wrapper never varies (brief: fixed spine).
AGENT_DOCS="domain.md issue-tracker.md triage-labels.md"
# The v1.0 slugs whose lingering presence forces a migrant reconcile.
STALE_SLUG_HYPHENATED="to-prd to-issues decision-mapping"
# Canonical status labels + orthogonal facets (translation-table target vocab).
CANON_LABELS=(
  "status: triage"
  "status: ready"
  "status: wip"
  "status: staged"
  "status: blocked"
  "afk"
  "needs-info"
)

# ---- detection ------------------------------------------------------------

has_origin() { git -C "$1" remote get-url origin >/dev/null 2>&1; }

# tracker-backed iff the repo has an origin remote; else trackerless-local.
detect_substrate() {
  if has_origin "$ROOT"; then printf 'tracker-backed'; else printf 'trackerless-local'; fi
}

# Version stamped by the last adopt run (empty when none — greenfield).
stamp_version() {
  local f="$ROOT/docs/agents/pocock-stamp.md"
  [ -f "$f" ] || return 0
  sed -n 's/^version:[[:space:]]*//p' "$f" | head -1
}

# Are any canonical agent-docs already present? (partial => migrant sub-case.)
has_agent_docs() {
  local d
  for d in $AGENT_DOCS; do
    [ -f "$ROOT/docs/agents/$d" ] && return 0
  done
  return 1
}

# Scan the wrapping layer for lingering v1.0 skill slugs -> sorted-unique list.
# Hyphenated slugs are distinctive enough to match bare; `review` only counts
# as an explicit `/review` invocation to avoid matching the English word.
scan_stale_slugs() {
  local -a files=()
  local f
  for f in CLAUDE.md AGENTS.md WORKFLOW.md \
           docs/agents/domain.md docs/agents/issue-tracker.md docs/agents/triage-labels.md; do
    [ -f "$ROOT/$f" ] && files+=("$ROOT/$f")
  done
  [ "${#files[@]}" -eq 0 ] && return 0
  {
    grep -hoE '\b(to-prd|to-issues|decision-mapping)\b' "${files[@]}" 2>/dev/null
    grep -hoE '/review\b' "${files[@]}" 2>/dev/null | sed 's#^/##'
  } | sort -u
}

# Source-of-truth slot: external when a vault/facts/contracts corpus is present.
detect_source_of_truth() {
  if [ -d "$ROOT/vault" ] || [ -d "$ROOT/facts" ] || [ -d "$ROOT/contracts" ]; then
    printf 'external'
  else
    printf 'in-repo'
  fi
}

# Freshness within the substrate. Greenfield needs no installed-version lookup;
# current-vs-migrant is decided by the stamp/slug signals, layered.
detect_freshness() {
  local stamp="$1" stale="$2" have_docs="$3" installed
  if [ -n "$stale" ]; then printf 'migrant'; return; fi
  if [ -n "$stamp" ]; then
    installed="${POCOCK_INSTALLED_VERSION:-}"
    if [ -n "$installed" ] && [ "$stamp" = "$installed" ]; then printf 'current'; else printf 'migrant'; fi
    return
  fi
  # No stamp, no stale slugs: a bare repo is greenfield; stray agent-docs are a
  # partial/provisional prior state -> migrant (backfill, don't clobber).
  if [ "$have_docs" -eq 1 ]; then printf 'migrant'; else printf 'greenfield'; fi
}

# ---- JSON rendering (hand-rolled, jq-free, deterministic) ------------------

# Emit a JSON string array at 2-space indent `pad`. Empty -> "[]" inline.
json_array() { # pad item...
  local pad="$1"; shift
  if [ "$#" -eq 0 ]; then printf '[]'; return; fi
  printf '[\n'
  local i=1 n="$#"
  for item in "$@"; do
    if [ "$i" -lt "$n" ]; then printf '%s  "%s",\n' "$pad" "$item"
    else                       printf '%s  "%s"\n'  "$pad" "$item"; fi
    i=$((i+1))
  done
  printf '%s]' "$pad"
}

# null when empty, else a quoted JSON string.
json_str_or_null() { [ -n "$1" ] && printf '"%s"' "$1" || printf 'null'; }

emit_plan() {
  local substrate freshness stamp sot
  local -a stale=() slots_intent=("structural" "voice" "capability")
  local -a artifacts=(
    "docs/agents/domain.md"
    "docs/agents/issue-tracker.md"
    "docs/agents/triage-labels.md"
    "docs/agents/pocock-stamp.md"
    "CLAUDE.md#agent-skills"
  )

  substrate="$(detect_substrate)"
  stamp="$(stamp_version)"
  sot="$(detect_source_of_truth)"
  while IFS= read -r s; do [ -n "$s" ] && stale+=("$s"); done < <(scan_stale_slugs)
  local have_docs=0; has_agent_docs && have_docs=1
  freshness="$(detect_freshness "$stamp" "${stale[*]:-}" "$have_docs")"

  printf '{\n'
  printf '  "substrate": "%s",\n' "$substrate"
  printf '  "freshness": "%s",\n' "$freshness"
  printf '  "stamp_version": %s,\n' "$(json_str_or_null "$stamp")"
  printf '  "stale_slugs": %s,\n' "$(json_array '  ' "${stale[@]}")"
  printf '  "proposed_slots": {\n'
  printf '    "source_of_truth": "%s",\n' "$sot"
  printf '    "lifecycle_overlay": "status-kanban",\n'
  printf '    "idea_to_issue_gate": "open",\n'
  printf '    "prs_as_request_surface": false,\n'
  printf '    "area_labels": [],\n'
  printf '    "board_scope": "own",\n'
  printf '    "intent": %s\n' "$(json_array '    ' "${slots_intent[@]}")"
  printf '  },\n'
  # Greenfield/migrant re-discover bindings live (#35); nothing is cached yet.
  printf '  "cached_bindings": null,\n'
  printf '  "artifacts_to_write": %s,\n' "$(json_array '  ' "${artifacts[@]}")"
  printf '  "labels_to_create": %s\n' "$(json_array '  ' "${CANON_LABELS[@]}")"
  printf '}\n'
}

# ---- main -----------------------------------------------------------------

main() {
  if [ "$JSON" -eq 1 ]; then
    emit_plan
  else
    # Human summary echoes the load-bearing classification.
    local substrate freshness
    substrate="$(detect_substrate)"
    local stamp; stamp="$(stamp_version)"
    local -a stale=(); while IFS= read -r s; do [ -n "$s" ] && stale+=("$s"); done < <(scan_stale_slugs)
    local have_docs=0; has_agent_docs && have_docs=1
    freshness="$(detect_freshness "$stamp" "${stale[*]:-}" "$have_docs")"
    printf 'pocock-plan (dry-run): substrate=%s freshness=%s stamp=%s\n' \
      "$substrate" "$freshness" "${stamp:-none}"
  fi
}

main
