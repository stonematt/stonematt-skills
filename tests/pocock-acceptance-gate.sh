#!/usr/bin/env bash
# ============================================================================
# Pocock runtime acceptance gate + issue-lifecycle smoke — TEST SEAM 1 (#66)
# ============================================================================
# One seam over the WHOLE /stone-adopt-pocock run. It proves the LLM-led half by
# OUTCOME, never by internal reasoning (design of record: docs/briefs/
# adopt-pocock-wrapper.md, "Testing Decisions, Seam 1"). It grows from and
# SUPERSEDES the held-out e2e smoke seed (#59, the old pocock-e2e-smoke.sh).
#
# HARD GATE — this must FAIL LOUDLY. A weaker model must not be able to silently
# ship a bad adoption: any missed success criterion (Part A) or any broken board
# wiring (Part B) exits nonzero with a clear message. "The map built
# successfully" is NOT proof of correct wiring.
#
# Two parts:
#
#   Part A — runtime acceptance gate. After an adoption run, assert the declared
#   success criteria against the resulting repo: spine present (or the corpus
#   subset), the `## Agent skills` block, canonical labels created (or `[]` for a
#   corpus), the version stamp written, NO lingering v1.0 references, NO
#   provisional banner, and ALL tracker-touching roles bound (stamp `unresolved`
#   empty). Any miss => nonzero + a clear FAIL line.
#
#   Part B — behavioral smoke (anti-silent-success). Create a THROWAWAY issue,
#   move it across the status:* lanes (triage -> ready -> wip -> staged), close
#   it (done), confirm the board/lane state reflects the progression, then CLEAN
#   THE ISSUE UP. Cleanup is GUARANTEED (trap-backed) so a mid-smoke failure
#   still removes the throwaway — no litter left in the tracker.
#
# ---------------------------------------------------------------------------
# TWO RUN MODES
# ---------------------------------------------------------------------------
#   Default (OFFLINE self-verify) — deterministic, no network, no tokens. Part A
#   runs against golden + broken fixture "adopted repos" (proving it PASSES a
#   good adoption and FAILS LOUDLY on each single miss); Part B runs against a
#   fake `gh` shim (proving the create -> move -> close -> cleanup logic, incl.
#   guaranteed cleanup on an injected mid-smoke crash). This is what the AFK gate
#   (tests/run-all.sh, via test-pocock-gate.sh) runs.
#       bash tests/pocock-acceptance-gate.sh
#
#   LIVE (POCOCK_SMOKE_LIVE=1) — the real gate the SKILL runs at adoption time on
#   a TARGET repo. Part A asserts the real adopted repo; Part B drives a real
#   throwaway issue on a real tracker (real `gh` + scripts/pocock-board.sh). This
#   is INHERENTLY live (network + authorization) and is DELIBERATELY excluded
#   from run-all. Required env:
#       POCOCK_SMOKE_LIVE=1
#       POCOCK_TARGET_REPO=/path/to/adopted/repo   # for Part A
#       POCOCK_TARGET_MODE=tracker|corpus          # default tracker
#       POCOCK_SMOKE_REPO=owner/repo               # throwaway-issue target
#     e.g.  POCOCK_SMOKE_LIVE=1 POCOCK_TARGET_REPO=/tmp/adopted \
#           POCOCK_SMOKE_REPO=me/scratch bash tests/pocock-acceptance-gate.sh
# ============================================================================
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
. "$TESTS_DIR/lib.sh"

CANON_LABELS=("status: triage" "status: ready" "status: wip" "status: staged" \
              "status: blocked" "afk" "needs-info")

# ============================================================================
# PART A — runtime acceptance gate
# ============================================================================
# gate_assert_adopted <repo_dir> <mode>   mode = tracker | corpus
# Prints one "GATE PASS/FAIL [<tag>] ..." line per criterion. Returns 0 iff every
# criterion holds; 1 on ANY miss. This is the product (what runs live at adoption
# time); the offline self-verify below drives it against golden + broken repos.
gate_assert_adopted() {
  local R="$1" mode="${2:-tracker}"
  local ad="$R/docs/agents" claude="$R/CLAUDE.md" stamp="$R/docs/agents/pocock-stamp.md"
  local miss=0

  # 1. Spine present (or the corpus subset for a trackerless-local repo).
  if [ "$mode" = corpus ]; then
    if [ -d "$R/facts" ] && [ -f "$ad/domain.md" ]; then
      echo "  GATE PASS [spine] corpus subset present (facts/ + docs/agents/domain.md)"
    else
      echo "  GATE FAIL [spine] corpus subset missing (need facts/ + docs/agents/domain.md)"; miss=1
    fi
  else
    if [ -f "$ad/issue-tracker.md" ] && [ -f "$ad/triage-labels.md" ] && [ -f "$ad/domain.md" ]; then
      echo "  GATE PASS [spine] docs/agents trio present"
    else
      echo "  GATE FAIL [spine] docs/agents trio incomplete (issue-tracker/triage-labels/domain)"; miss=1
    fi
  fi

  # 2. `## Agent skills` block present in CLAUDE.md.
  if grep -qF '## Agent skills' "$claude" 2>/dev/null; then
    echo "  GATE PASS [agent-skills] ## Agent skills block present in CLAUDE.md"
  else
    echo "  GATE FAIL [agent-skills] CLAUDE.md missing the '## Agent skills' block"; miss=1
  fi

  # 3. Canonical labels created (recorded in the stamp), or [] for a corpus.
  if [ "$mode" = corpus ]; then
    if grep -qE '^labels:[[:space:]]*\[\][[:space:]]*$' "$stamp" 2>/dev/null; then
      echo "  GATE PASS [labels] corpus stamp carries labels: []"
    else
      echo "  GATE FAIL [labels] corpus stamp must carry 'labels: []'"; miss=1
    fi
  else
    local l lmiss=""
    for l in "${CANON_LABELS[@]}"; do
      grep -qF "$l" "$stamp" 2>/dev/null || lmiss="$lmiss; $l"
    done
    if [ -z "$lmiss" ]; then
      echo "  GATE PASS [labels] canonical label set recorded in the stamp"
    else
      echo "  GATE FAIL [labels] canonical labels missing from stamp:$lmiss"; miss=1
    fi
  fi

  # 4. Version stamp written.
  if [ -f "$stamp" ] && grep -qE '^suite_version:' "$stamp" 2>/dev/null; then
    echo "  GATE PASS [stamp] docs/agents/pocock-stamp.md written with suite_version"
  else
    echo "  GATE FAIL [stamp] docs/agents/pocock-stamp.md missing or has no suite_version"; miss=1
  fi

  # Collect the wrapping layer (CLAUDE.md + docs/agents/*.md) for the prose scans.
  local wl=()
  [ -f "$claude" ] && wl+=("$claude")
  local f
  for f in "$ad"/*.md; do [ -f "$f" ] && wl+=("$f"); done

  # 5. No lingering v1.0 references in the wrapping layer. The `/review` match is
  #    anchored to a slash-command boundary (POSIX ERE, BSD-grep safe) so a
  #    `src/review/` path or `code-review` word does NOT count as the v1.0
  #    `/review` command (the slice-#66 path-false-positive fix).
  local slugs=""
  if [ "${#wl[@]}" -gt 0 ]; then
    slugs="$(grep -hoE '\b(to-prd|to-issues|decision-mapping|to-review)\b' "${wl[@]}" 2>/dev/null | sort -u | tr '\n' ' ')"
    if grep -qE '(^|[^[:alnum:]._/-])/review([^[:alnum:]/_-]|$)' "${wl[@]}" 2>/dev/null; then
      slugs="$slugs /review"
    fi
  fi
  if [ -z "$(printf '%s' "$slugs" | tr -d '[:space:]')" ]; then
    echo "  GATE PASS [v1-refs] no lingering v1.0 slugs in the wrapping layer"
  else
    echo "  GATE FAIL [v1-refs] lingering v1.0 slug(s) in the wrapping layer: $slugs"; miss=1
  fi

  # 6. No provisional banner.
  if [ "${#wl[@]}" -gt 0 ] && grep -qi 'provisional' "${wl[@]}" 2>/dev/null; then
    echo "  GATE FAIL [banner] a provisional banner is still present in the wrapping layer"; miss=1
  else
    echo "  GATE PASS [banner] no provisional banner in the wrapping layer"
  fi

  # 7. All tracker-touching roles bound: stamp `unresolved` empty and no unbound
  #    placeholder. A non-empty `unresolved` means the run stopped-and-surfaced
  #    and is NOT fully adopted.
  if [ -f "$stamp" ] \
     && grep -qE '^unresolved:[[:space:]]*\[\][[:space:]]*$' "$stamp" 2>/dev/null \
     && ! grep -qF '<discovered>' "$stamp" 2>/dev/null; then
    echo "  GATE PASS [roles-bound] all tracker-touching roles bound (unresolved empty)"
  else
    echo "  GATE FAIL [roles-bound] stamp unresolved non-empty or unbound placeholder present"; miss=1
  fi

  return "$miss"
}

# ============================================================================
# PART B — behavioral smoke (anti-silent-success)
# ============================================================================
# Drives a throwaway issue across the status:* lanes with $GH (real gh live, or
# the fake shim offline), asserting the lane/board state after every move, then
# closes and DELETES it. Cleanup is guaranteed by a trap on the lifecycle
# subshell, so an injected mid-smoke crash (POCOCK_SMOKE_FORCE_FAIL=1) still
# removes the throwaway. Assertions use file-backed s_ok/s_bad so results survive
# the subshell boundary.
smoke_behavioral() { # <work_dir>
  local W="$1"
  mkdir -p "$W"
  local flag="$W/smoke.fail"; : > "$flag"
  local s_ok  s_bad
  s_ok()  { echo "  smoke ok   $1"; }
  s_bad() { echo "  smoke FAIL $1"; echo 1 >> "$flag"; }
  s_has() { case "$1" in *"$2"*) s_ok "$3" ;; *) s_bad "$3 (missing [$2] in [$1])" ;; esac; }
  local recorded="$W/.throwaway-num"

  # Ensure the canonical labels exist on the target (also exercises the board
  # helper's `labels` verb — "the board actually runs").
  POCOCK_GH="$GH" bash "$REPO_ROOT/scripts/pocock-board.sh" labels >/dev/null 2>&1 || true

  (
    # --- lifecycle subshell: trap-backed guaranteed cleanup -----------------
    _cleanup() {
      local n; n="$(cat "$recorded" 2>/dev/null || true)"
      [ -n "$n" ] || return 0
      "$GH" issue delete "$n" --yes >/dev/null 2>&1 \
        || "$GH" issue close "$n"        >/dev/null 2>&1 || true
      rm -f "$recorded"
    }
    trap '_cleanup' EXIT

    local url num
    url="$("$GH" issue create \
             --title "pocock-acceptance-smoke throwaway (delete me)" \
             --label "status: triage" \
             --body "Throwaway issue for the Pocock acceptance smoke. Auto-deleted." )" \
      || { s_bad "issue create failed"; exit 1; }
    num="$(printf '%s\n' "$url" | tail -1)"; num="${num##*/}"
    printf '%s\n' "$num" > "$recorded"    # record BEFORE anything can fail => cleanup covers it
    [ -n "$num" ] || { s_bad "issue create returned no number"; exit 1; }
    s_ok "throwaway issue #$num created"

    # Injected mid-smoke crash: prove cleanup still fires (self-verify only).
    if [ "${POCOCK_SMOKE_FORCE_FAIL:-0}" = 1 ]; then
      echo "  smoke (injected mid-smoke crash after create — cleanup must still run)"
      exit 7
    fi

    s_has "$("$GH" issue view "$num" --json labels --jq '.labels[].name')" \
          "status: triage" "issue starts in the triage lane"

    local prev="triage" lane
    for lane in ready wip staged; do
      "$GH" issue edit "$num" --remove-label "status: $prev" --add-label "status: $lane" >/dev/null 2>&1 \
        || { s_bad "relabel to $lane failed"; exit 1; }
      s_has "$("$GH" issue view "$num" --json labels --jq '.labels[].name')" \
            "status: $lane" "board reflects move to the $lane lane"
      prev="$lane"
    done

    "$GH" issue close "$num" >/dev/null 2>&1 || { s_bad "issue close failed"; exit 1; }
    local st; st="$("$GH" issue view "$num" --json state --jq '.state')"
    case "$st" in
      CLOSED|closed) s_ok "issue #$num closed (done lane)" ;;
      *)             s_bad "issue #$num not closed (state=$st)" ;;
    esac

    _cleanup   # explicit cleanup on the happy path (trap re-runs it: idempotent)
  )

  # A nonzero subshell exit that is NOT the injected crash is a real failure.
  local rc=$?
  if [ "$rc" -ne 0 ] && [ "${POCOCK_SMOKE_FORCE_FAIL:-0}" != 1 ]; then
    s_bad "lifecycle subshell exited nonzero ($rc)"
  fi

  # Return nonzero iff any smoke assertion failed.
  [ ! -s "$flag" ]
}

# ============================================================================
# MAIN
# ============================================================================
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

if [ "${POCOCK_SMOKE_LIVE:-0}" = 1 ]; then
  echo "== Seam 1: LIVE acceptance gate + behavioral smoke =="

  # ---- Part A (live): assert the real adopted target repo ------------------
  TARGET="${POCOCK_TARGET_REPO:-}"
  MODE="${POCOCK_TARGET_MODE:-tracker}"
  if [ -n "$TARGET" ] && [ -d "$TARGET" ]; then
    echo "-- Part A: acceptance gate on $TARGET ($MODE) --"
    if gate_assert_adopted "$TARGET" "$MODE"; then
      _ok "Part A: adopted repo satisfies every success criterion"
    else
      _bad "Part A: adopted repo MISSED a success criterion (see GATE FAIL above)"
    fi
  else
    _bad "Part A: POCOCK_TARGET_REPO must point at the adopted repo dir (got '$TARGET')"
  fi

  # ---- Part B (live): real throwaway issue on a real tracker ---------------
  REPO="${POCOCK_SMOKE_REPO:-}"
  case "$REPO" in
    "")               _bad "Part B: POCOCK_SMOKE_REPO=owner/repo is required for the live smoke" ;;
    *stonematt-skills*) _bad "Part B: refusing to run the live smoke against '$REPO' (this repo's tracker)" ;;
    *)
      echo "-- Part B: behavioral smoke on $REPO --"
      export GH_REPO="$REPO"           # target the throwaway repo without --repo everywhere
      GH="${POCOCK_SMOKE_GH:-gh}"
      if smoke_behavioral "$WORK"; then
        _ok "Part B: throwaway issue driven across lanes + cleaned up"
      else
        _bad "Part B: behavioral smoke failed (see smoke FAIL above)"
      fi
      ;;
  esac

else
  echo "== Seam 1: OFFLINE self-verify (no network, no tokens) =="
  . "$TESTS_DIR/pocock-gate-fixtures.sh"
  FX="$WORK/fixtures"
  build_pocock_gate_fixtures "$FX"

  # ---- Part A self-verify: gate PASSES good adoptions ----------------------
  echo "-- Part A: gate passes a correctly-adopted repo --"
  OUT="$(gate_assert_adopted "$FX/adopted-tracker" tracker)"; rc=$?
  assert_eq 0 "$rc" "golden tracker repo passes the gate (exit 0)"
  assert_not_contains "$OUT" "GATE FAIL" "golden tracker repo trips zero criteria"

  OUT="$(gate_assert_adopted "$FX/adopted-corpus" corpus)"; rc=$?
  assert_eq 0 "$rc" "golden trackerless corpus passes the gate (exit 0)"
  assert_not_contains "$OUT" "GATE FAIL" "golden corpus trips zero criteria"

  # ---- Part A self-verify: gate FAILS LOUDLY on each single miss -----------
  echo "-- Part A: gate fails loudly on each missed criterion --"
  check_break() { # fixture  tag  msg
    local fx="$1" tag="$2" msg="$3" out rc
    out="$(gate_assert_adopted "$FX/$fx" tracker)"; rc=$?
    assert_eq 1 "$rc" "$msg => nonzero exit"
    assert_contains "$out" "GATE FAIL [$tag]" "$msg => trips [$tag]"
  }
  check_break broken-spine      spine       "missing spine doc"
  check_break broken-agentskills agent-skills "missing ## Agent skills block"
  check_break broken-labels     labels      "incomplete canonical labels"
  check_break broken-stamp      stamp       "missing version stamp"
  check_break broken-v1ref      v1-refs     "lingering /to-prd v1.0 slug"
  check_break broken-banner     banner      "provisional banner present"
  check_break broken-unbound    roles-bound "unresolved roles (non-empty)"

  # A single break must not spuriously trip other criteria (precision spot-check).
  OUT="$(gate_assert_adopted "$FX/broken-spine" tracker)"
  assert_not_contains "$OUT" "GATE FAIL [labels]"      "broken-spine does not spuriously fail [labels]"
  assert_not_contains "$OUT" "GATE FAIL [roles-bound]" "broken-spine does not spuriously fail [roles-bound]"

  # ---- Part B self-verify: behavioral-smoke LOGIC + guaranteed cleanup -----
  echo "-- Part B: behavioral smoke logic (offline shim) --"
  chmod +x "$TESTS_DIR/pocock-smoke-gh-shim" 2>/dev/null || true
  export GH="$TESTS_DIR/pocock-smoke-gh-shim"

  # Happy path: create -> move across lanes -> close -> cleanup.
  export POCOCK_SMOKE_STATE="$WORK/state-happy"; mkdir -p "$POCOCK_SMOKE_STATE"
  if smoke_behavioral "$WORK/happy"; then
    _ok "smoke happy path: lane progression + close all pass"
  else
    _bad "smoke happy path failed"
  fi
  LEFT="$(ls "$POCOCK_SMOKE_STATE"/issue-*.state 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq 0 "$LEFT" "smoke happy path cleans up the throwaway issue (no litter)"

  # Guaranteed cleanup: inject a mid-smoke crash right after issue creation and
  # confirm the trap still deleted the throwaway.
  export POCOCK_SMOKE_STATE="$WORK/state-crash"; mkdir -p "$POCOCK_SMOKE_STATE"
  POCOCK_SMOKE_FORCE_FAIL=1 smoke_behavioral "$WORK/crash" >/dev/null 2>&1 || true
  LEFT="$(ls "$POCOCK_SMOKE_STATE"/issue-*.state 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq 0 "$LEFT" "smoke cleanup is GUARANTEED even on a mid-smoke crash (no litter)"
fi

finish "pocock-acceptance-gate"
