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

build_pocock_fixtures() {
  local R="$1"
  rm -rf "$R"; mkdir -p "$R"

  # greenfield tracker-backed: origin remote, no docs/agents, no stamp, no slugs.
  _pocock_mkrepo "$R/greenfield"
  _pocock_remote "$R/greenfield" "git@github.com:stonematt/greenfield.git"
}
