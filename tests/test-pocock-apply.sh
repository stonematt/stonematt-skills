#!/usr/bin/env bash
# Greenfield apply test: pocock-apply consumes the plan and fully wires a fresh
# repo — labels created, docs trio + CLAUDE.md block + stamp written — then
# refuses (and does not clobber) on a re-run once the repo is no longer greenfield.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"
. "$TESTS_DIR/pocock-suite-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
build_pocock_fixtures "$SANDBOX"
build_pocock_suite_fixtures "$SANDBOX/suite"

REPO="$SANDBOX/greenfield"
chmod +x "$TESTS_DIR/gh-label-shim"
LABELLOG="$SANDBOX/labels.log"; : > "$LABELLOG"

export POCOCK_GH="$TESTS_DIR/gh-label-shim"
export GH_LABEL_LOG="$LABELLOG"
export POCOCK_INSTALLED_VERSION="1.4.0"
export POCOCK_STAMP_DATE="2026-07-12"
# Live role-binding (#53): apply discovers bindings from the installed suite and
# caches the recipe into the stamp. The current suite reproduces the static table.
export POCOCK_SUITE_DIR="$SANDBOX/suite/current"

OUT="$(bash "$SCRIPTS_DIR/pocock-apply.sh" --root "$REPO" 2>&1)"
RC=$?

assert_eq 0 "$RC" "greenfield apply exits 0"
assert_contains "$OUT" "greenfield — wiring" "apply reports greenfield wiring"

# ---- agent-doc trio -------------------------------------------------------
assert_file "$REPO/docs/agents/domain.md"        "domain.md written"
assert_file "$REPO/docs/agents/issue-tracker.md" "issue-tracker.md written"
assert_file "$REPO/docs/agents/triage-labels.md" "triage-labels.md written"

# ---- static translation table present in triage-labels --------------------
TRIAGE="$(cat "$REPO/docs/agents/triage-labels.md")"
assert_contains "$TRIAGE" "ready-for-agent" "triage-labels carries canonical role"
assert_contains "$TRIAGE" '`status: ready` **+** `afk`' "translation table maps ready-for-agent -> status:ready + afk"

# ---- CLAUDE.md `## Agent skills` block ------------------------------------
assert_file "$REPO/CLAUDE.md" "CLAUDE.md written"
CLAUDE="$(cat "$REPO/CLAUDE.md")"
assert_contains "$CLAUDE" "## Agent skills" "CLAUDE.md has ## Agent skills block"
BLOCKS="$(grep -c '^## Agent skills' "$REPO/CLAUDE.md")"
assert_eq "1" "$BLOCKS" "exactly one ## Agent skills block"

# ---- stamp ----------------------------------------------------------------
assert_file "$REPO/docs/agents/pocock-stamp.md" "pocock-stamp.md written"
STAMP="$(cat "$REPO/docs/agents/pocock-stamp.md")"
assert_contains "$STAMP" "version: 1.4.0"        "stamp records installed version"
assert_contains "$STAMP" "stamped: 2026-07-12"   "stamp records stamped date"
assert_contains "$STAMP" "Translation table"     "stamp carries the static translation table"

# ---- live role-binding recipe cached into the stamp (#53) ------------------
assert_not_contains "$STAMP" "bindings: null"    "stamp no longer defers bindings (suite available)"
for b in "on-ramp: wayfinder" "spec: to-spec" "slice-to-tickets: to-tickets" \
         "implement: implement" "review: code-review" \
         "setup: setup-matt-pocock-skills" "wayfinder: wayfinder"; do
  assert_contains "$STAMP" "$b" "stamp caches live binding: $b"
done
# AC6 pure-expand: the cached bindings equal what pocock-bind emits for the suite.
EXPECT_BINDINGS="$(bash "$SCRIPTS_DIR/pocock-bind.sh" --suite "$POCOCK_SUITE_DIR" \
                    --version 1.4.0 --format bindings-block)"
STAMP_BINDINGS="$(awk '/^bindings:/{f=1;next} /^[^ ]/{f=0} f{print}' "$REPO/docs/agents/pocock-stamp.md")"
assert_eq "$EXPECT_BINDINGS" "$STAMP_BINDINGS" "stamp bindings == live-discovered recipe (pure expand)"

# ---- labels created via gh (recording shim) -------------------------------
LABELS="$(cat "$LABELLOG")"
for l in "status: triage" "status: ready" "status: wip" "status: staged" \
         "status: blocked" "afk" "needs-info"; do
  assert_contains "$LABELS" "$l" "label created: $l"
done
LABEL_COUNT="$(grep -c . "$LABELLOG")"
assert_eq "7" "$LABEL_COUNT" "exactly 7 canonical labels created"

# ---- fully-wired proof: plan now classifies the repo as NOT greenfield ----
POST="$(bash "$SCRIPTS_DIR/pocock-plan.sh" --dry-run --json --root "$REPO" 2>/dev/null)"
assert_not_contains "$POST" '"freshness": "greenfield"' "wired repo no longer reads greenfield"

# ---- idempotency guard: re-run refuses (exit 3), does not clobber ----------
STAMP_BEFORE="$(cat "$REPO/docs/agents/pocock-stamp.md")"
: > "$LABELLOG"
OUT2="$(bash "$SCRIPTS_DIR/pocock-apply.sh" --root "$REPO" 2>&1)"; RC2=$?
assert_eq 3 "$RC2" "re-run on wired repo refuses (exit 3)"
assert_contains "$OUT2" "only greenfield is supported" "refusal explains greenfield-only scope"
STAMP_AFTER="$(cat "$REPO/docs/agents/pocock-stamp.md")"
assert_eq "$STAMP_BEFORE" "$STAMP_AFTER" "refused re-run left the stamp untouched"
assert_eq "0" "$(grep -c . "$LABELLOG")" "refused re-run created no labels"

# ---- SKILL.md skeleton present + manual-only ------------------------------
SKILL="$SCRIPTS_DIR/../skills/in-progress/stone-adopt-pocock/SKILL.md"
assert_file "$SKILL" "adopt-pocock SKILL.md present"
SKILL_BODY="$(cat "$SKILL")"
assert_contains "$SKILL_BODY" "disableModelInvocation: true" "SKILL.md is manual-only (disableModelInvocation)"
assert_contains "$SKILL_BODY" "name: stone-adopt-pocock" "SKILL.md frontmatter name matches folder"

finish "pocock-apply"
