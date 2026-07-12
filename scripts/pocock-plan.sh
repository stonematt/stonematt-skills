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

# Source-of-truth slot (R1): where the repo's canonical artifact lives. Names
# the external corpus rather than collapsing to a bare "external", so the
# detect-then-confirm proposal is specific enough to act on: in-repo (default)
# vs an external vault / contracts+ADRs / facts corpus. Precedence when several
# coexist is deterministic (vault > contracts > facts) — the dev corrects if
# the guess is wrong; the seam never fabricates.
detect_source_of_truth() {
  if   [ -d "$ROOT/vault" ];     then printf 'vault'
  elif [ -d "$ROOT/contracts" ]; then printf 'contracts'
  elif [ -d "$ROOT/facts" ];     then printf 'facts'
  else                                printf 'in-repo'
  fi
}

# Lifecycle-overlay slot (R2): kanban / flat / identity — proposed, not
# hardcoded. Tracker-backed repos get the canonical `status:*` kanban spine;
# a trackerless-local corpus has no GitHub board to run lanes on, so `flat` is
# the honest proposal. `identity` (no board projection at all) is the third
# value a dev may correct to; the seam proposes, the human confirms.
detect_lifecycle_overlay() { # substrate
  case "$1" in
    tracker-backed) printf 'kanban' ;;
    *)              printf 'flat'   ;;
  esac
}

# Idea->issue-gate slot (R3): governance/docs repos forbid `to-tickets` on raw
# ideas — an ADR/spec must land first. A `docs/adr/` or `docs/briefs/` corpus
# is the signal that the repo runs spec-first; otherwise the gate is `open`.
detect_idea_to_issue_gate() {
  if [ -d "$ROOT/docs/adr" ] || [ -d "$ROOT/docs/briefs" ]; then
    printf 'spec-first'
  else
    printf 'open'
  fi
}

# Origin remote owner (org/user login), empty when there is no origin. Handles
# both scp-style (git@host:owner/repo.git) and URL (https://host/owner/repo.git)
# remotes by mapping ':' to a path separator and taking the second-to-last
# non-empty segment.
remote_owner() {
  local url
  url="$(git -C "$ROOT" remote get-url origin 2>/dev/null)" || return 0
  [ -n "$url" ] || return 0
  url="${url%.git}"; url="${url//:/\/}"
  printf '%s\n' "$url" | awk -F/ '{ n=NF; while (n>0 && $n=="") n--; if (n>=2) print $(n-1) }'
}

# Board-scope slot (R6): `own` vs a `shared` org Project. A member of a shared
# org board is proposed `shared`; the human confirms/overrides downstream
# (--board-scope on pocock-board / pocock-member). Detection is offline: the
# origin remote owner matched against POCOCK_SHARED_ORGS (space/colon-separated
# org logins that own a shared board). No signal => `own` (the safe default, so
# the proposal never silently mistakes a personal repo for a member).
detect_board_scope() {
  local owner orgs o
  owner="$(remote_owner)"
  [ -n "$owner" ] || { printf 'own'; return; }
  orgs="${POCOCK_SHARED_ORGS:-}"; orgs="${orgs//:/ }"
  for o in $orgs; do
    [ "$o" = "$owner" ] && { printf 'shared'; return; }
  done
  printf 'own'
}

# ---- wiring signals (consumed by the preflight gate, #54) ------------------
# The emitter is the single detection authority; the gate never re-scans the
# tree — it reads these booleans off the plan. Keep all filesystem probing here.

doc_present() { [ -f "$ROOT/docs/agents/$1" ]; }

# issue-tracker.md is *reconciled* iff present and carrying no "provisional /
# not reconciled" banner (a partial prior run leaves the banner behind).
issue_tracker_reconciled() {
  local f="$ROOT/docs/agents/issue-tracker.md"
  [ -f "$f" ] || return 1
  grep -qiE 'provisional|not[[:space:]]*reconciled' "$f" && return 1
  return 0
}

# Roles are bound iff the stamp records a non-empty `bindings:` block (canonical
# roles mapped to the installed skills). No stamp or an empty block => unbound.
roles_bound() {
  local f="$ROOT/docs/agents/pocock-stamp.md"
  [ -f "$f" ] || return 1
  awk '
    /^bindings:[[:space:]]*$/ { inb=1; next }
    inb && /^[^[:space:]]/    { inb=0 }
    inb && /^[[:space:]]+[^[:space:]#-]/ { found=1 }
    END { exit(found?0:1) }
  ' "$f"
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

# Echo a JSON boolean for a command's success (0 => true).
json_bool() { if "$@"; then printf 'true'; else printf 'false'; fi; }

emit_plan() {
  local substrate freshness stamp sot overlay gate board_scope
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
  overlay="$(detect_lifecycle_overlay "$substrate")"
  gate="$(detect_idea_to_issue_gate)"
  board_scope="$(detect_board_scope)"
  while IFS= read -r s; do [ -n "$s" ] && stale+=("$s"); done < <(scan_stale_slugs)
  local have_docs=0; has_agent_docs && have_docs=1
  freshness="$(detect_freshness "$stamp" "${stale[*]:-}" "$have_docs")"

  printf '{\n'
  printf '  "substrate": "%s",\n' "$substrate"
  printf '  "freshness": "%s",\n' "$freshness"
  printf '  "stamp_version": %s,\n' "$(json_str_or_null "$stamp")"
  printf '  "stale_slugs": %s,\n' "$(json_array '  ' "${stale[@]}")"
  # Wiring signals — the preflight gate (#54) reads these off the plan so it
  # never duplicates the emitter's detection.
  printf '  "wiring": {\n'
  printf '    "issue_tracker_present": %s,\n'    "$(json_bool doc_present issue-tracker.md)"
  printf '    "issue_tracker_reconciled": %s,\n' "$(json_bool issue_tracker_reconciled)"
  printf '    "triage_labels_present": %s,\n'    "$(json_bool doc_present triage-labels.md)"
  printf '    "domain_present": %s,\n'           "$(json_bool doc_present domain.md)"
  printf '    "roles_bound": %s\n'               "$(json_bool roles_bound)"
  printf '  },\n'
  printf '  "proposed_slots": {\n'
  printf '    "source_of_truth": "%s",\n' "$sot"
  printf '    "lifecycle_overlay": "%s",\n' "$overlay"
  printf '    "idea_to_issue_gate": "%s",\n' "$gate"
  printf '    "prs_as_request_surface": false,\n'
  printf '    "area_labels": [],\n'
  printf '    "board_scope": "%s",\n' "$board_scope"
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
