#!/usr/bin/env bash
# Fixture builder for the Pocock runtime acceptance gate (Seam 1, Part A / #66).
#
# These are "adopted repos" — the OUTCOME of a /stone-adopt-pocock run, not
# input trees. The gate (gate_assert_adopted in tests/pocock-acceptance-gate.sh)
# asserts the declared success criteria against them offline, so we can prove the
# gate PASSES a correctly-adopted repo and FAILS LOUDLY on any single miss without
# spending tokens or an unattended agent.
#
# build_pocock_gate_fixtures <dir> writes:
#   adopted-tracker     a fully-adopted tracker-backed repo — passes every criterion
#   adopted-corpus      a fully-adopted trackerless-local corpus — passes (labels: [])
#   broken-spine        golden tracker minus a spine doc          => trips [spine]
#   broken-agentskills  golden tracker, CLAUDE.md lacks the block => trips [agent-skills]
#   broken-labels       golden tracker, stamp labels incomplete   => trips [labels]
#   broken-stamp        golden tracker minus the version stamp     => trips [stamp]
#   broken-v1ref        golden tracker + a lingering /to-prd slug   => trips [v1-refs]
#   broken-banner       golden tracker + a PROVISIONAL banner       => trips [banner]
#   broken-unbound      golden tracker, stamp unresolved non-empty  => trips [roles-bound]
#
# Each broken variant differs from golden by exactly ONE mutation, so a tripped
# criterion is unambiguous.

# --- stamp writer ------------------------------------------------------------
# The durable version stamp the Stone delta writes (see references/
# pocock-stamp.template.md). `labels_mode` and `unresolved_mode` let the broken
# variants perturb a single criterion:
#   labels_mode:     full | short | corpus
#   unresolved_mode: empty | nonempty
_gate_stamp() { # path suite_version substrate labels_mode unresolved_mode
  local p="$1" v="$2" substrate="$3" labels_mode="$4" unresolved_mode="$5"
  mkdir -p "$(dirname "$p")"
  {
    echo '---'
    echo "suite_version: \"$v\""
    echo 'stamped: 2026-07-12'
    echo "substrate: $substrate"
    echo 'board: none'
    case "$labels_mode" in
      corpus) echo 'labels: []' ;;
      short)  echo 'labels:'; echo '  - "afk"' ;;   # deliberately incomplete
      *)      echo 'labels:'
              for l in "status: triage" "status: ready" "status: wip" \
                       "status: staged" "status: blocked" "afk" "needs-info"; do
                echo "  - \"$l\""
              done ;;
    esac
    # live-discovered binding recipe — every tracker-touching role resolved.
    echo 'bindings:'
    echo '  on-ramp:          { skill: wayfinder,  via: skill-md }'
    echo '  spec:             { skill: to-spec,    via: changelog }'
    echo '  slice-to-tickets: { skill: to-tickets, via: skill-md }'
    echo '  implement:        { skill: implement-slice, via: skill-md }'
    echo '  review:           { skill: code-review, via: ask-matt }'
    echo '  setup:            { skill: setup-matt-pocock-skills, via: skill-md }'
    echo 'forked: []'
    case "$unresolved_mode" in
      nonempty)
        echo 'unresolved:'
        echo '  - review: two candidate skills, needs Matt' ;;
      *) echo 'unresolved: []' ;;
    esac
    echo '---'
    echo
    echo '# Pocock suite stamp'
    echo
    echo 'Bindings discovered live; a future run reads this to tell current from drifted.'
  } > "$p"
}

_gate_agent_docs() { # repo   (the reconciled spine trio)
  local ad="$1/docs/agents"
  mkdir -p "$ad"
  printf '# Issue tracker: GitHub\n\nReconciled config. Uses `/code-review` for PRs.\n' > "$ad/issue-tracker.md"
  printf '# Triage labels\n\nstatus:* lifecycle vocabulary; `afk` is orthogonal.\n'     > "$ad/triage-labels.md"
  printf '# Domain\n\nGlossary and ubiquitous language.\n'                              > "$ad/domain.md"
}

# The wrapping-layer CLAUDE.md the delta rewrites. Carries the ## Agent skills
# block and, on purpose, a `src/review/` path + `code-review` prose — these must
# NOT trip the anchored /review v1.0 scan (the slice-#66 path-false-positive fix).
_gate_claude() { # repo
  cat > "$1/CLAUDE.md" <<'EOF'
# CLAUDE.md

## Project
An adopted repo.

## Agent skills
Bound to the Pocock suite via `stone-adopt-pocock`. The review stage lives in
`src/review/` (see src/review/vault.py); use `/code-review` for PRs.
EOF
}

# A fully-adopted, tracker-backed repo that passes every gate criterion.
_gate_golden_tracker() { # repo [labels_mode] [unresolved_mode]
  local r="$1" labels_mode="${2:-full}" unresolved_mode="${3:-empty}"
  mkdir -p "$r"
  _gate_agent_docs "$r"
  _gate_claude "$r"
  _gate_stamp "$r/docs/agents/pocock-stamp.md" "1.4.0" "tracker-backed" "$labels_mode" "$unresolved_mode"
}

# A fully-adopted, trackerless-local corpus (facts/ is the artifact; labels: []).
_gate_golden_corpus() { # repo
  local r="$1"
  mkdir -p "$r/facts" "$r/sources" "$r/refs" "$r/docs/agents"
  printf 'A distilled claim.\n' > "$r/facts/claim-1.md"
  printf '# Domain\n\nCorpus glossary.\n' > "$r/docs/agents/domain.md"
  cat > "$r/CLAUDE.md" <<'EOF'
# CLAUDE.md

## Project
A trackerless-local corpus.

## Agent skills
Corpus subset: domain doc + stamp, no tracker machinery.
EOF
  _gate_stamp "$r/docs/agents/pocock-stamp.md" "1.4.0" "trackerless-local" "corpus" "empty"
}

build_pocock_gate_fixtures() { # base_dir
  local B="$1"
  rm -rf "$B"; mkdir -p "$B"

  _gate_golden_tracker "$B/adopted-tracker"
  _gate_golden_corpus  "$B/adopted-corpus"

  # Each broken variant = golden tracker + exactly one mutation.
  _gate_golden_tracker "$B/broken-spine"
  rm -f "$B/broken-spine/docs/agents/triage-labels.md"

  _gate_golden_tracker "$B/broken-agentskills"
  printf '# CLAUDE.md\n\n## Project\nNo agent-skills block here.\n' > "$B/broken-agentskills/CLAUDE.md"

  _gate_golden_tracker "$B/broken-labels" short

  _gate_golden_tracker "$B/broken-stamp"
  rm -f "$B/broken-stamp/docs/agents/pocock-stamp.md"

  _gate_golden_tracker "$B/broken-v1ref"
  printf '\nLegacy: run `/to-prd` then `/to-issues` to slice work.\n' >> "$B/broken-v1ref/CLAUDE.md"

  _gate_golden_tracker "$B/broken-banner"
  printf '# Issue tracker: GitHub\n\n> PROVISIONAL / not reconciled — seed defaults.\n' \
    > "$B/broken-banner/docs/agents/issue-tracker.md"

  _gate_golden_tracker "$B/broken-unbound" full nonempty
}
