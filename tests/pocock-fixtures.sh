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

# The installed Pocock suite the migrant seam diffs the stamp against. Injected
# into pocock-migrant via POCOCK_INSTALLED_CATALOG so drift math is deterministic
# (real runs read ~/.agents/skills). Carries the light whole-catalog map (name +
# dmi + activated), the tracker-touching bindings, and the changelog-declared
# contract-changed class (the silent-breakage drift a live SKILL.md re-read finds).
_pocock_installed_catalog() { # path version
  local f="$1" v="$2"
  cat > "$f" <<EOF
{
  "version": "$v",
  "catalog": [
    {"name": "wayfinder",       "dmi": false, "activated": true},
    {"name": "to-spec",         "dmi": false, "activated": true},
    {"name": "to-tickets",      "dmi": false, "activated": true},
    {"name": "code-review",     "dmi": false, "activated": true},
    {"name": "diagnosing-bugs", "dmi": false, "activated": true}
  ],
  "bindings": {
    "on-ramp": "wayfinder",
    "spec": "to-spec",
    "slice-to-tickets": "to-tickets",
    "review": "code-review"
  },
  "contract_changed": [
    "to-spec: writes docs/briefs/<name>.md then stops (was an inline PRD issue)"
  ]
}
EOF
}

# A fuller stamp carrying the light catalog map + bindings, for migrant drift
# tests. `kind` selects the catalog/binding shape:
#   installed  — matches _pocock_installed_catalog exactly (=> current, no drift)
#   legacy     — the pre-rename v1.x suite (to-review not yet code-review, no
#                diagnosing-bugs) => renamed/added/removed/bindings-shifted drift
_pocock_stamp_catalog() { # path version kind
  local p="$1" v="$2" kind="$3"
  mkdir -p "$p/docs/agents"
  if [ "$kind" = "installed" ]; then
    cat > "$p/docs/agents/pocock-stamp.md" <<EOF
---
suite: matt-pocock-skills
version: $v
stamped: 2026-07-01
source: ~/.agents/skills
catalog:
  - wayfinder|dmi=false|activated=true
  - to-spec|dmi=false|activated=true
  - to-tickets|dmi=false|activated=true
  - code-review|dmi=false|activated=true
  - diagnosing-bugs|dmi=false|activated=true
bindings:
  on-ramp: wayfinder
  spec: to-spec
  slice-to-tickets: to-tickets
  review: code-review
---

# Pocock stamp
EOF
  else
    cat > "$p/docs/agents/pocock-stamp.md" <<EOF
---
suite: matt-pocock-skills
version: $v
stamped: 2026-07-01
source: ~/.agents/skills
catalog:
  - wayfinder|dmi=false|activated=true
  - to-spec|dmi=false|activated=true
  - to-tickets|dmi=false|activated=true
  - to-review|dmi=false|activated=true
bindings:
  on-ramp: wayfinder
  spec: to-spec
  slice-to-tickets: to-tickets
  review: to-review
---

# Pocock stamp
EOF
  fi
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

  # missing-docs: reconciled tracker + bound stamp, but triage/domain absent.
  _pocock_mkrepo "$R/missing-docs"
  _pocock_remote "$R/missing-docs" "git@github.com:stonematt/missing-docs.git"
  mkdir -p "$R/missing-docs/docs/agents"
  printf '# Issue tracker: GitHub\n\nReconciled config.\n' \
    > "$R/missing-docs/docs/agents/issue-tracker.md"
  _pocock_stamp "$R/missing-docs" "1.1.0"

  # ---- migrant / current fixtures (#52) ------------------------------------
  # One installed catalog (version 1.4.0) is the drift target for all three.
  _pocock_installed_catalog "$R/installed-catalog.json" "1.4.0"

  # current: reconciled trio + stamp whose version AND catalog match installed,
  # no stale slugs => freshness current => near-noop patch, no drift file.
  _pocock_mkrepo "$R/current"
  _pocock_remote "$R/current" "git@github.com:stonematt/current.git"
  _pocock_agent_docs "$R/current"
  _pocock_stamp_catalog "$R/current" "1.4.0" installed

  # migrant-stale-stamp: reconciled trio, NO stale slugs, but the stamp records a
  # legacy version 1.1.0 (to-review pre-rename, no diagnosing-bugs) => the stamp
  # alone forces migrant; drift = renamed/added/removed/bindings-shifted.
  _pocock_mkrepo "$R/migrant-stale-stamp"
  _pocock_remote "$R/migrant-stale-stamp" "git@github.com:stonematt/migrant-stale-stamp.git"
  _pocock_agent_docs "$R/migrant-stale-stamp"
  _pocock_stamp_catalog "$R/migrant-stale-stamp" "1.1.0" legacy

  # migrant-no-stamp: reconciled trio, NO stamp at all, but CLAUDE.md still cites
  # v1.0 slugs (/to-prd, /to-issues) => the slug-scan alone forces migrant even
  # with no stamp; drift = added (whole installed catalog) + stale-refs.
  _pocock_mkrepo "$R/migrant-no-stamp"
  _pocock_remote "$R/migrant-no-stamp" "git@github.com:stonematt/migrant-no-stamp.git"
  _pocock_agent_docs "$R/migrant-no-stamp"
  printf '# CLAUDE.md\n\nRun `/to-prd` then `/to-issues` to slice work.\n' \
    > "$R/migrant-no-stamp/CLAUDE.md"
}
