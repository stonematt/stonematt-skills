#!/usr/bin/env bash
# Contextual-slot detection test (#55): the plan-emitter PROPOSES slot values
# from inspection — source-of-truth seam, lifecycle overlay, idea->issue gate,
# intent set, PRs-as-request-surface, area labels — mutating nothing. The dev
# confirms or corrects (an LLM/human step in SKILL.md); this test pins the
# deterministic proposal seam those confirmations start from.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
. "$TESTS_DIR/pocock-fixtures.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT

# --- fixtures: one repo per detectable slot signal -------------------------
# Reuse the shared repo helpers (_pocock_mkrepo / _pocock_remote) so the trees
# match the plan-emitter's other fixtures.

# tracker-backed repo with an external SoT corpus dir.
_slot_repo_with_dir() { # name corpusdir
  local p="$SANDBOX/$1"
  _pocock_mkrepo "$p"
  _pocock_remote "$p" "git@github.com:stonematt/$1.git"
  mkdir -p "$p/$2"
  echo x > "$p/$2/keep"
}

_slot_repo_with_dir vault-repo     vault
_slot_repo_with_dir contracts-repo contracts
_slot_repo_with_dir facts-repo     facts

# spec-first governance signal: a docs/adr corpus present.
_pocock_mkrepo "$SANDBOX/gov-repo"
_pocock_remote "$SANDBOX/gov-repo" "git@github.com:stonematt/gov-repo.git"
mkdir -p "$SANDBOX/gov-repo/docs/adr"
echo x > "$SANDBOX/gov-repo/docs/adr/0001-x.md"

# trackerless-local: no origin remote -> no GitHub board to run lanes on.
_pocock_mkrepo "$SANDBOX/local-repo"

# bare tracker-backed repo: no external corpus, no governance dirs.
_pocock_mkrepo "$SANDBOX/plain-repo"
_pocock_remote "$SANDBOX/plain-repo" "git@github.com:stonematt/plain-repo.git"

plan() { bash "$SCRIPTS_DIR/pocock-plan.sh" --dry-run --json --root "$SANDBOX/$1" 2>/dev/null; }

# --- source-of-truth seam: in-repo / vault / contracts / facts -------------
assert_contains "$(plan vault-repo)"     '"source_of_truth": "vault"'     "vault/ dir => source_of_truth=vault"
assert_contains "$(plan contracts-repo)" '"source_of_truth": "contracts"' "contracts/ dir => source_of_truth=contracts"
assert_contains "$(plan facts-repo)"     '"source_of_truth": "facts"'     "facts/ dir => source_of_truth=facts"
assert_contains "$(plan plain-repo)"     '"source_of_truth": "in-repo"'   "no corpus dir => source_of_truth=in-repo"

# --- lifecycle overlay: kanban / flat / identity ---------------------------
assert_contains "$(plan plain-repo)" '"lifecycle_overlay": "kanban"' "tracker-backed => overlay proposed kanban"
assert_contains "$(plan local-repo)" '"lifecycle_overlay": "flat"'   "trackerless-local => overlay proposed flat"

# --- idea->issue gate: open / spec-first -----------------------------------
assert_contains "$(plan gov-repo)"   '"idea_to_issue_gate": "spec-first"' "docs/adr present => spec-first gate"
assert_contains "$(plan plain-repo)" '"idea_to_issue_gate": "open"'       "no governance dirs => open gate"

# --- PRs-as-request-surface boolean, default no ----------------------------
assert_contains "$(plan plain-repo)" '"prs_as_request_surface": false' "prs-as-request-surface defaults false"

# --- area labels never fabricated (empty/emergent across every repo) -------
for r in vault-repo contracts-repo facts-repo gov-repo local-repo plain-repo; do
  assert_contains "$(plan "$r")" '"area_labels": []' "area labels empty/emergent in $r"
done

# --- intent set proposed (the repo-kind seed) ------------------------------
INTENT="$(plan plain-repo)"
assert_contains "$INTENT" '"intent": ['   "intent set present"
assert_contains "$INTENT" '"structural"'  "intent carries structural"
assert_contains "$INTENT" '"voice"'       "intent carries voice"
assert_contains "$INTENT" '"capability"'  "intent carries capability"

# --- the proposal seam mutates nothing -------------------------------------
BEFORE="$(git -C "$SANDBOX/plain-repo" status --porcelain)"
plan plain-repo >/dev/null
AFTER="$(git -C "$SANDBOX/plain-repo" status --porcelain)"
assert_eq "$BEFORE" "$AFTER" "slot proposal leaves the repo untouched"

# every proposed plan is valid JSON.
for r in vault-repo contracts-repo facts-repo gov-repo local-repo plain-repo; do
  if plan "$r" | python3 -m json.tool >/dev/null 2>&1; then
    _ok "plan for $r is valid JSON"
  else
    _bad "plan for $r is not valid JSON"
  fi
done

finish "pocock-slots"
