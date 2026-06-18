#!/usr/bin/env bash
# Fixture builder for journal-sweep tests.
# build_fixtures <dir> creates a sandbox repo tree in known states.
# Reference clock for these fixtures: TODAY=2026-06-18, YESTERDAY=2026-06-17.

_mkrepo() { # path commit-date
  local p="$1" d="$2"
  mkdir -p "$p"
  git -C "$p" init -q -b main
  git -C "$p" config user.email test@local
  git -C "$p" config user.name "Fixture"
  echo x > "$p/f.txt"; git -C "$p" add f.txt
  GIT_AUTHOR_DATE="${d}T12:00:00" GIT_COMMITTER_DATE="${d}T12:00:00" \
    git -C "$p" commit -q -m "work $d"
}
_entry()  { mkdir -p "$1/.journal/docs/journal"; printf -- '---\ndate: %s\n---\nbody\n' "$2" > "$1/.journal/docs/journal/$2.md"; }
_remote() { git -C "$1" remote add origin "$2"; }

build_fixtures() {
  local R="$1"
  rm -rf "$R"; mkdir -p "$R"

  # stale: entry 06-13, commit 06-17 -> stale 06-14..06-17
  _mkrepo "$R/github.com/stonematt/stale-repo" 2026-06-17
  _entry  "$R/github.com/stonematt/stale-repo" 2026-06-13
  # nested independent repo (.git DIR) and submodule-style (.git FILE) — both must be skipped (pruned at root)
  mkdir -p "$R/github.com/stonematt/stale-repo/nested/.git"
  mkdir -p "$R/github.com/stonematt/stale-repo/vendor/sub"
  echo "gitdir: /elsewhere" > "$R/github.com/stonematt/stale-repo/vendor/sub/.git"

  # current: entry 06-17, commit 06-16 -> current
  _mkrepo "$R/github.com/stonematt/current-repo" 2026-06-16
  _entry  "$R/github.com/stonematt/current-repo" 2026-06-17

  # empty journal worktree, no entries -> empty
  _mkrepo "$R/github.com/stonematt/empty-journal" 2026-06-17
  mkdir -p "$R/github.com/stonematt/empty-journal/.journal"

  # owned, no .journal -> discover
  _mkrepo "$R/github.com/stonematt/discover-me" 2026-06-17
  _remote "$R/github.com/stonematt/discover-me" "git@github.com:stonematt/discover-me.git"

  # foreign, no .journal -> ignore
  _mkrepo "$R/github.com/randovendor/foreign" 2026-06-17
  _remote "$R/github.com/randovendor/foreign" "https://github.com/randovendor/foreign.git"

  # multi-week gap: entry 05-30, commit 06-17 -> stale 05-31..06-17
  _mkrepo "$R/github.com/stonematt/gap-repo" 2026-06-17
  _entry  "$R/github.com/stonematt/gap-repo" 2026-05-30

  # only new work is TODAY (06-18): entry 06-17, commit 06-18 -> current (today excluded)
  _mkrepo "$R/github.com/stonematt/today-only" 2026-06-18
  _entry  "$R/github.com/stonematt/today-only" 2026-06-17

  # linked worktree: .git is a FILE -> not a repo, not emitted
  mkdir -p "$R/github.com/stonematt/linked-worktree"
  echo "gitdir: /elsewhere/.git/worktrees/x" > "$R/github.com/stonematt/linked-worktree/.git"

  # local-only (no remote) with .journal: entry 06-15, commit 06-17 -> stale 06-16..06-17
  _mkrepo "$R/localonly" 2026-06-17
  _entry  "$R/localonly" 2026-06-15
}
