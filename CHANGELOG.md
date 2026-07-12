# Changelog

All notable changes to this skill pack are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the pack is
versioned with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The canonical version number lives in `.claude-plugin/plugin.json`. Each release
tag (`vMAJOR.MINOR.PATCH`) on `main` matches that number — see `scripts/release.sh`.
Consumers can check whether their install is current with `scripts/check-latest.sh`.

## [Unreleased]

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

[Unreleased]: https://github.com/stonematt/stonematt-skills/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/stonematt/stonematt-skills/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/stonematt/stonematt-skills/releases/tag/v0.1.0
