#!/usr/bin/env bash
# Fixture builder for pocock-bind (live role-binding) tests.
# build_pocock_suite_fixtures <dir> creates installed-suite trees modeling the
# states the binder must handle: a clean current suite, a rename (release-notes
# authority), a split (ambiguous), a vanished role (empty), an ask-matt rescue,
# and a suite carrying forked commit/merge skills.

# _mkskill <suite-dir> <slug> [description] [extra-frontmatter-line]
_mkskill() {
  local suite="$1" slug="$2" desc="${3:-$slug skill}" extra="${4:-}"
  mkdir -p "$suite/$slug"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$slug"
    printf 'description: %s\n' "$desc"
    [ -n "$extra" ] && printf '%s\n' "$extra"
    printf -- '---\n\n# %s\n' "$slug"
  } > "$suite/$slug/SKILL.md"
}

# The seven skills that cleanly fill the tracker-touching roles on the current
# suite (one skill per role => a clean, unambiguous bind).
_mk_current_suite() { # suite-dir
  local s="$1"
  _mkskill "$s" wayfinder                 "On-ramp: chart the work and route decisions."
  _mkskill "$s" to-spec                   "Turn a brief into a spec document."
  _mkskill "$s" to-tickets                "Slice a spec into child issues."
  _mkskill "$s" implement                 "Implement an issue on a feature branch."
  _mkskill "$s" code-review               "Review a branch or PR for standards and spec."
  _mkskill "$s" setup-matt-pocock-skills  "Set up the Pocock skill suite in a repo."
}

build_pocock_suite_fixtures() {
  local R="$1"
  rm -rf "$R"; mkdir -p "$R"

  # current: the clean, fully-installed suite at the stamped version. Every role
  # binds via authority 2 (installed SKILL.md); output == the static table.
  _mk_current_suite "$R/current"
  printf '1.4.0\n' > "$R/current/VERSION"

  # renamed: `to-spec` shipped as `spec-it`; release notes announce the rename.
  # Authority 1 (release notes) resolves it — authority 2 alone would miss.
  _mk_current_suite "$R/renamed"
  rm -rf "$R/renamed/to-spec"
  _mkskill "$R/renamed" spec-it "Turn a brief into a spec document (renamed from to-spec)."
  printf '2.0.0\n' > "$R/renamed/VERSION"
  printf '# Release notes 2.0.0\n\nbind spec spec-it\n' > "$R/renamed/release-notes.md"

  # split: the review role now matches two installed skills (code-review AND a
  # legacy `review`) and nothing disambiguates => ambiguous => stop-and-surface.
  _mk_current_suite "$R/split"
  _mkskill "$R/split" review "Legacy review skill (shadows code-review)."
  printf '3.0.0\n' > "$R/split/VERSION"

  # vanished: the review skill was removed entirely => empty bind => stop.
  _mk_current_suite "$R/vanished"
  rm -rf "$R/vanished/code-review"
  printf '3.1.0\n' > "$R/vanished/VERSION"

  # ask-matt-rescue: an ambiguous review split, but the ask-matt router ships a
  # role-map that disambiguates (authority 3) => resolved, source=ask-matt.
  _mk_current_suite "$R/ask-matt-rescue"
  _mkskill "$R/ask-matt-rescue" review "Legacy review skill."
  mkdir -p "$R/ask-matt-rescue/ask-matt"
  printf 'review code-review\n' > "$R/ask-matt-rescue/ask-matt/role-map.txt"
  printf '3.2.0\n' > "$R/ask-matt-rescue/VERSION"

  # forked: a clean current suite that ALSO carries Matt Stone's forked
  # commit/merge skills. These must be flagged, never bound or rewritten.
  _mk_current_suite "$R/forked"
  _mkskill "$R/forked" stone-commit "Matt's forked commit skill." "fork-of: pocock-commit"
  _mkskill "$R/forked" stone-merge  "Matt's forked merge skill."  "fork-of: pocock-merge"
  printf '1.4.0\n' > "$R/forked/VERSION"
}
