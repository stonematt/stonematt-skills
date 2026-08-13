# Changelog

All notable changes to this skill pack are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the pack is
versioned with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The canonical version number lives in `.claude-plugin/plugin.json`. Each release
tag (`vMAJOR.MINOR.PATCH`) on `main` matches that number — see `scripts/release.sh`.
Consumers can check whether their install is current with `scripts/check-latest.sh`.

## [Unreleased]

## [0.3.0] - 2026-07-28

Two of the seven skills in the pack manifest change in this release —
`stone-commit` and `stone-merge`. Everything else below is preview or
repo-internal and does not reach a `npx skills add` / marketplace install.

### Changed
- `stone-commit` now detects **multiple** linked tickets on one branch and emits
  one `Closes #N` line per ticket. Detection leads with tickets named in the
  session and `#N` refs in commit messages; the `feat/<n>-slug` branch-name regex
  drops to a legacy fallback, since the canonical branch convention carries no
  issue token. Candidates are filtered to open issues, and `/to-tickets` parent
  issues holding open sub-issues are dropped so a batch PR can't auto-close a
  spec. `Closes` lines are emitted on `dev` PRs too — the keyword is inert there,
  but `stone-merge` reads it to stage each ticket.
- `stone-merge` strips **every** upstream `status:` lane when staging a ticket
  (`wip`, `ready`, `triage`), not just `wip`. A ticket can reach `staged` from any
  of them: autonomous work often merges straight from `ready`, and a bug filed
  and fixed in one sitting never leaves `triage`.

### Fixed
- `stone-adopt-pocock` (**preview** — in `skills/in-progress/`, not in the pack
  manifest): `pocock-board.sh` bound Projects v2 GraphQL variables with
  `gh api -F`, which type-infers its value, so an all-digit option id crossed the
  wire as an Int and the mutation was rejected against a `String!` variable. All
  bindings are now `-f`. (#89)

### Internal
- `afk-ready` → `afk` as the canonical triage flag, across the repo docs and the
  live GitHub label. `afk-ready` is now a legacy alias to migrate. The pack ships
  no triage vocabulary to consumers, so this changes nothing downstream.
- `stone-adopt-pocock` preview: workbench reframed as the loop rather than a
  deferred slice, plus a transient de-GSD nudge in delta reconcile. (#84)
- Brief specifying deterministic CI sync workflow templates for
  `stone-adopt-pocock`, replacing per-run prose generation
  (`docs/briefs/ci-workflow-templates.md`).

## [0.2.0] - 2026-07-12

### Added
- `stone-adopt-pocock` wrapper skill (**preview** — ships in
  `skills/in-progress/`, not yet in the pack manifest). One idempotent
  install-or-upgrade path that adopts Matt Pocock's skill-suite on any repo: runs
  Pocock's own `setup-matt-pocock-skills`, then overlays only the Stone delta —
  translation-table conventions, a durable version stamp carrying a
  live-discovered role-binding recipe, a stale-v1.0 rewrite, and an optional
  Projects v2 board. Includes a read-only preflight readiness gate, a gitignored
  workbench learning ledger, and a runtime acceptance gate + issue-lifecycle
  smoke (Test Seam 1).
- Versioning system: `scripts/release.sh` (tag + GitHub Release driven off
  `plugin.json`), `scripts/check-latest.sh` (consumer freshness check), a
  `VERSION` marker stamped into claude.ai zips, and this changelog.

### Changed
- Branch flow formalized as `feature → dev → main` (`dev` = integration/default,
  `main` = release). Tracker + agent docs updated to match.

## [0.1.0] - 2026-06-19

### Added
- Baseline release. `stone-*` skill pack: `stone-commit`, `stone-merge`,
  `stone-promote-settings`, `stone-ai-sniff-test`, `stone-client-report`,
  `stone-journal`, `stone-journal-status`.
- Cross-surface install paths: `npx skills add`, Claude Code plugin marketplace,
  claude.ai zip upload.
- Nightly auto-journaling sweep (`scripts/journal-sweep.sh`) with launchd
  install/uninstall/run helpers.

[Unreleased]: https://github.com/stonematt/stonematt-skills/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/stonematt/stonematt-skills/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/stonematt/stonematt-skills/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/stonematt/stonematt-skills/releases/tag/v0.1.0
