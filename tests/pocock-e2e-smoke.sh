#!/usr/bin/env bash
# Held-out e2e SMOKE for the adopt-Pocock wrapper (#59) — the layer ABOVE the
# deterministic seam. It runs a REAL /stone-adopt-pocock skill invocation against
# fixture repos and snapshots the emitted artifacts (labels, agent docs, version
# stamp, drift report). Covers the two paths that write config:
#   T2 greenfield — scaffold a fresh repo (pocock-apply seam)
#   T3 migrant    — upgrade a version-bumped repo + emit the drift report
#
# Like tests/phase0-smoke.sh, this is a HARD GATE that spends real tokens and runs
# an UNATTENDED agent (bypassPermissions). It is deliberately NOT part of
# tests/run-all.sh (the AFK gate). Run it once, when you've authorized headless
# claude:
#   bash tests/pocock-e2e-smoke.sh
#
# GitHub is never mutated: label creation is routed through the recording
# gh-label-shim and the fixture repos have fake origins, so no real repo is
# touched. Snapshots land under a temp dir (printed at the end); override with
# POCOCK_SMOKE_SNAPSHOT=/some/dir to keep them.
#
# To self-verify the harness WITHOUT tokens, point it at the bundled shim that
# drives the same seam scripts a real agent would:
#   POCOCK_SMOKE_CLAUDE=tests/pocock-smoke-claude-shim bash tests/pocock-e2e-smoke.sh
#
# If this is RED, the agent-judgment layer above the seam is broken — stop and
# report before trusting an unattended adopt run.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
. "$TESTS_DIR/pocock-fixtures.sh"
. "$TESTS_DIR/pocock-suite-fixtures.sh"

CLAUDE="${POCOCK_SMOKE_CLAUDE:-claude}"
STAMP_DATE="${POCOCK_STAMP_DATE:-$(date +%F)}"
DRIFT_DATE="${POCOCK_DRIFT_DATE:-$STAMP_DATE}"

SANDBOX="$(mktemp -d)"
SNAP="${POCOCK_SMOKE_SNAPSHOT:-$SANDBOX/snapshot}"
mkdir -p "$SNAP"
build_pocock_fixtures "$SANDBOX"
build_pocock_suite_fixtures "$SANDBOX/suite"
chmod +x "$TESTS_DIR/gh-label-shim" "$TESTS_DIR/pocock-smoke-claude-shim"

# Deterministic env for the seam scripts the skill drives. A real run reads the
# live ~/.agents/skills suite; here we inject a fixed suite/catalog + dates so the
# emitted artifacts are reproducible and snapshot-diffable.
export POCOCK_GH="$TESTS_DIR/gh-label-shim"
export POCOCK_INSTALLED_VERSION="${POCOCK_INSTALLED_VERSION:-1.4.0}"
export POCOCK_STAMP_DATE="$STAMP_DATE"
export POCOCK_SUITE_DIR="$SANDBOX/suite/current"
export POCOCK_INSTALLED_CATALOG="$SANDBOX/installed-catalog.json"
export POCOCK_DRIFT_DATE="$DRIFT_DATE"

fail=0
_pass() { echo "PASS $1"; }
_fail() { echo "FAIL $1"; fail=1; }
check_file()     { [ -f "$1" ] && _pass "$2" || _fail "$2 (missing $1)"; }
check_has()      { grep -qF "$2" "$1" 2>/dev/null && _pass "$3" || _fail "$3"; }

# Make the wrapper skill + its seam scripts discoverable from inside a fixture
# repo, exactly as a real project-local deploy would (.claude/skills + scripts/).
install_wrapper() { # repo
  local r="$1"
  mkdir -p "$r/.claude/skills"
  ln -sf "$REPO_ROOT/skills/in-progress/stone-adopt-pocock" "$r/.claude/skills/stone-adopt-pocock"
  ln -sf "$REPO_ROOT/scripts" "$r/scripts"
}

invoke() { # repo prompt
  local r="$1" prompt="$2"
  ( cd "$r" && GH_LABEL_LOG="$r/labels.log" timeout 300 "$CLAUDE" -p "$prompt" \
      --model sonnet --permission-mode bypassPermissions )
}

# ---- T2: greenfield scaffold ---------------------------------------------
GF="$SANDBOX/greenfield"
install_wrapper "$GF"
: > "$GF/labels.log"
echo "== T2 greenfield: real /stone-adopt-pocock in $GF =="
invoke "$GF" "/stone-adopt-pocock: adopt this greenfield repo to the standing Pocock-suite config. Non-interactive smoke run — accept the detected slot defaults, do not prompt, and skip the optional board/CI projection."
gfrc=$?

# Snapshot the greenfield artifacts.
mkdir -p "$SNAP/greenfield/docs/agents"
cp "$GF"/docs/agents/*.md "$SNAP/greenfield/docs/agents/" 2>/dev/null || true
cp "$GF/CLAUDE.md"        "$SNAP/greenfield/CLAUDE.md"     2>/dev/null || true
cp "$GF/labels.log"       "$SNAP/greenfield/labels.log"   2>/dev/null || true

echo "---- T2 greenfield artifacts ----"
[ "$gfrc" -eq 0 ] && _pass "greenfield run exits 0" || _fail "greenfield run exit=$gfrc"
check_file "$SNAP/greenfield/docs/agents/domain.md"        "domain.md emitted"
check_file "$SNAP/greenfield/docs/agents/issue-tracker.md" "issue-tracker.md emitted"
check_file "$SNAP/greenfield/docs/agents/triage-labels.md" "triage-labels.md emitted"
check_file "$SNAP/greenfield/docs/agents/pocock-stamp.md"  "pocock-stamp.md emitted"
check_file "$SNAP/greenfield/CLAUDE.md"                    "CLAUDE.md emitted"
check_has  "$SNAP/greenfield/CLAUDE.md" "## Agent skills"  "CLAUDE.md carries ## Agent skills block"
check_has  "$SNAP/greenfield/docs/agents/pocock-stamp.md" "version: $POCOCK_INSTALLED_VERSION" "stamp records installed version"
for l in "status: triage" "status: ready" "status: wip" "status: staged" \
         "status: blocked" "afk" "needs-info"; do
  check_has "$SNAP/greenfield/labels.log" "$l" "label emitted: $l"
done

# ---- T3: migrant upgrade + drift report ----------------------------------
MG="$SANDBOX/migrant-stale-stamp"
install_wrapper "$MG"
: > "$MG/labels.log"
echo "== T3 migrant: real /stone-adopt-pocock in $MG =="
invoke "$MG" "/stone-adopt-pocock: this repo is a version-bump migrant. Run the migrant upgrade — reconcile config, rewrite the wrapping layer, and write the dated drift report."
mgrc=$?

DRIFT="$MG/docs/agents/pocock-drift-$DRIFT_DATE.md"
mkdir -p "$SNAP/migrant/docs/agents"
cp "$MG"/docs/agents/*.md "$SNAP/migrant/docs/agents/" 2>/dev/null || true

echo "---- T3 migrant artifacts ----"
[ "$mgrc" -eq 0 ] && _pass "migrant run exits 0" || _fail "migrant run exit=$mgrc"
check_file "$SNAP/migrant/docs/agents/pocock-drift-$DRIFT_DATE.md" "dated drift report emitted"
for h in "### Renamed / merged" "### Contract-changed" "### Added" \
         "### Removed" "### Bindings-shifted" "### Stale refs"; do
  check_has "$SNAP/migrant/docs/agents/pocock-drift-$DRIFT_DATE.md" "$h" "drift group present: $h"
done

echo "----"
echo "snapshot: $SNAP"
if [ "$fail" -eq 0 ]; then echo "POCOCK-E2E: GREEN"; else echo "POCOCK-E2E: RED"; fi
exit "$fail"
