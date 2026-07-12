#!/usr/bin/env bash
# Trackerless-local test (#57): a repo with no origin remote is a
# facts/ + sources/ + refs/ corpus, not a GitHub tracker. The plan must classify it
# trackerless (golden), recognize the corpus, and force NO tracker machinery; apply
# must wire the corpus config (domain + stamp + CLAUDE block) and skip labels + the
# two tracker docs.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_fixtures "$SANDBOX"

REPO="$SANDBOX/trackerless"
GOLDEN="$TESTS_DIR/golden/pocock-trackerless.json"

# ---- plan: golden diff (the tested seam) + mutates nothing ----------------
BEFORE="$(git -C "$REPO" status --porcelain)"
GOT="$(bash "$SCRIPTS_DIR/pocock-plan.sh" --dry-run --json --root "$REPO" 2>/dev/null)"
RC=$?
assert_eq 0 "$RC" "plan-emitter exits 0"

WANT="$(cat "$GOLDEN")"
if [ "$GOT" = "$WANT" ]; then
  _ok "trackerless plan matches golden"
else
  _bad "trackerless plan mismatch"
  echo "---- diff (< want / > got) ----"
  diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$GOT")
fi

if printf '%s\n' "$GOT" | python3 -m json.tool >/dev/null 2>&1; then
  _ok "plan is valid JSON"
else
  _bad "plan is not valid JSON"
fi

# Acceptance: no remote => trackerless-local; corpus recognized; no tracker forced.
assert_contains "$GOT" '"substrate": "trackerless-local"' "no origin remote => trackerless-local"
assert_contains "$GOT" '"source_of_truth": "facts-corpus"' "facts/+sources/+refs corpus recognized as the artifact"
assert_contains "$GOT" '"lifecycle_overlay": "none"'       "no status-kanban overlay forced on a corpus"
assert_contains "$GOT" '"board_scope": "none"'             "no board scope forced on a corpus"
assert_contains "$GOT" '"labels_to_create": []'            "no GitHub tracker labels forced"
assert_not_contains "$GOT" 'issue-tracker.md'              "tracker doc not in artifacts_to_write"
assert_not_contains "$GOT" 'triage-labels.md'              "triage-labels doc not in artifacts_to_write"
assert_contains "$GOT" '"docs/agents/domain.md"'           "domain doc still written (constant spine)"
assert_contains "$GOT" '"docs/agents/pocock-stamp.md"'     "stamp still written"

AFTER="$(git -C "$REPO" status --porcelain)"
assert_eq "$BEFORE" "$AFTER" "dry-run leaves the repo untouched"

# ---- apply: wires the corpus config, skips tracker-only steps -------------
chmod +x "$TESTS_DIR/gh-label-shim"
LABELLOG="$SANDBOX/labels.log"; : > "$LABELLOG"
export POCOCK_GH="$TESTS_DIR/gh-label-shim"
export GH_LABEL_LOG="$LABELLOG"
export POCOCK_INSTALLED_VERSION="1.4.0"
export POCOCK_STAMP_DATE="2026-07-12"

OUT="$(bash "$SCRIPTS_DIR/pocock-apply.sh" --root "$REPO" 2>&1)"
RCA=$?
assert_eq 0 "$RCA" "trackerless apply exits 0"
assert_contains "$OUT" "substrate=trackerless-local" "apply reports trackerless substrate"

# Corpus config written.
assert_file "$REPO/docs/agents/domain.md"       "domain.md written"
assert_file "$REPO/docs/agents/pocock-stamp.md" "pocock-stamp.md written"
assert_file "$REPO/CLAUDE.md"                   "CLAUDE.md written"

# Tracker-only docs NOT written (no GitHub tracker forced).
assert_nofile "$REPO/docs/agents/issue-tracker.md" "issue-tracker.md NOT written on a corpus"
assert_nofile "$REPO/docs/agents/triage-labels.md" "triage-labels.md NOT written on a corpus"

# CLAUDE.md carries the corpus block, not the tracker block.
CLAUDE="$(cat "$REPO/CLAUDE.md")"
assert_contains "$CLAUDE" "## Agent skills" "CLAUDE.md has ## Agent skills block"
assert_contains "$CLAUDE" "Corpus (source of truth)" "CLAUDE.md carries the corpus block"
assert_not_contains "$CLAUDE" "### Issue tracker" "CLAUDE.md omits the tracker block"

# Stamp records the substrate + no labels.
STAMP="$(cat "$REPO/docs/agents/pocock-stamp.md")"
assert_contains "$STAMP" "version: 1.4.0"              "stamp records installed version"
assert_contains "$STAMP" "substrate: trackerless-local" "stamp records trackerless substrate"
assert_contains "$STAMP" "labels: []"                 "stamp records no status labels"
assert_not_contains "$STAMP" "status: triage"          "stamp omits the status-label list"

# No labels created (tracker-only step skipped).
assert_eq "0" "$(grep -c . "$LABELLOG")" "no GitHub labels created on a corpus"
assert_contains "$OUT" "labels skipped (trackerless-local" "apply announces the label skip"

# Idempotency: re-run refuses (no longer greenfield) and does not clobber.
STAMP_BEFORE="$(cat "$REPO/docs/agents/pocock-stamp.md")"
OUT2="$(bash "$SCRIPTS_DIR/pocock-apply.sh" --root "$REPO" 2>&1)"; RC2=$?
assert_eq 3 "$RC2" "re-run on a wired corpus refuses (exit 3)"
assert_eq "$STAMP_BEFORE" "$(cat "$REPO/docs/agents/pocock-stamp.md")" "refused re-run left the stamp untouched"

finish "pocock-trackerless"
