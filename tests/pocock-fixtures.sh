#!/usr/bin/env bash
# Fixture builder for pocock-plan (adopt-Pocock wrapper) tests.
# build_pocock_fixtures <dir> creates repo trees in known adopt-states.

_pocock_mkrepo() { # path
  local p="$1"
  mkdir -p "$p"
  git -C "$p" init -q -b main
  git -C "$p" config user.email test@local
  git -C "$p" config user.name "Fixture"
  echo hi > "$p/README.md"; git -C "$p" add README.md
  GIT_AUTHOR_DATE=2026-07-01T12:00:00 GIT_COMMITTER_DATE=2026-07-01T12:00:00 \
    git -C "$p" commit -q -m init
}
_pocock_remote() { git -C "$1" remote add origin "$2"; }

# Write the canonical agent-docs trio (all reconciled) into a repo.
_pocock_agent_docs() { # path
  local p="$1"
  mkdir -p "$p/docs/agents"
  printf '# Issue tracker: GitHub\n\nReconciled config.\n' > "$p/docs/agents/issue-tracker.md"
  printf '# Triage labels\n\nstatus:* lifecycle.\n'        > "$p/docs/agents/triage-labels.md"
  printf '# Domain\n\nGlossary.\n'                          > "$p/docs/agents/domain.md"
}

# Write a version stamp with a non-empty bindings block (roles bound).
_pocock_stamp() { # path version
  local p="$1" v="$2"
  mkdir -p "$p/docs/agents"
  cat > "$p/docs/agents/pocock-stamp.md" <<EOF
---
suite: matt-pocock-skills
version: $v
stamped: 2026-07-01
source: ~/.agents/skills
bindings:
  on-ramp: wayfinder
  spec: to-spec
  slice-to-tickets: to-tickets
  review: code-review
---

# Pocock stamp
EOF
}

build_pocock_fixtures() {
  local R="$1"
  rm -rf "$R"; mkdir -p "$R"

  # greenfield tracker-backed: origin remote, no docs/agents, no stamp, no slugs.
  _pocock_mkrepo "$R/greenfield"
  _pocock_remote "$R/greenfield" "git@github.com:stonematt/greenfield.git"

  # wired: reconciled trio + bound stamp + no stale slugs => gate PASSES.
  _pocock_mkrepo "$R/wired"
  _pocock_remote "$R/wired" "git@github.com:stonematt/wired.git"
  _pocock_agent_docs "$R/wired"
  _pocock_stamp "$R/wired" "1.1.0"

  # provisional: like wired but the tracker doc still carries the banner.
  _pocock_mkrepo "$R/provisional"
  _pocock_remote "$R/provisional" "git@github.com:stonematt/provisional.git"
  _pocock_agent_docs "$R/provisional"
  _pocock_stamp "$R/provisional" "1.1.0"
  printf '# Issue tracker: GitHub\n\n> PROVISIONAL / not reconciled — seed defaults.\n' \
    > "$R/provisional/docs/agents/issue-tracker.md"

  # stale: fully wired but CLAUDE.md still references a v1.0 slug.
  _pocock_mkrepo "$R/stale"
  _pocock_remote "$R/stale" "git@github.com:stonematt/stale.git"
  _pocock_agent_docs "$R/stale"
  _pocock_stamp "$R/stale" "1.1.0"
  printf '# CLAUDE.md\n\nRun `/to-prd` then `/to-issues`.\n' > "$R/stale/CLAUDE.md"

  # trackerless-local: NO origin remote; a facts/ + sources/ + refs/ corpus is the
  # artifact (not a GitHub tracker). Greenfield freshness: no docs/agents, no stamp.
  _pocock_mkrepo "$R/trackerless"
  mkdir -p "$R/trackerless/facts" "$R/trackerless/sources" "$R/trackerless/refs"
  printf 'A distilled claim.\n'    > "$R/trackerless/facts/claim-1.md"
  printf 'Primary material.\n'     > "$R/trackerless/sources/source-1.md"
  printf 'Supporting reference.\n' > "$R/trackerless/refs/ref-1.md"
  git -C "$R/trackerless" add facts sources refs
  GIT_AUTHOR_DATE=2026-07-01T12:00:00 GIT_COMMITTER_DATE=2026-07-01T12:00:00 \
    git -C "$R/trackerless" commit -q -m corpus

  # missing-docs: reconciled tracker + bound stamp, but triage/domain absent.
  _pocock_mkrepo "$R/missing-docs"
  _pocock_remote "$R/missing-docs" "git@github.com:stonematt/missing-docs.git"
  mkdir -p "$R/missing-docs/docs/agents"
  printf '# Issue tracker: GitHub\n\nReconciled config.\n' \
    > "$R/missing-docs/docs/agents/issue-tracker.md"
  _pocock_stamp "$R/missing-docs" "1.1.0"
}
