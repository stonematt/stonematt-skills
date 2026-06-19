# Changelog

All notable changes to this skill pack are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the pack is
versioned with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The canonical version number lives in `.claude-plugin/plugin.json`. Each release
tag (`vMAJOR.MINOR.PATCH`) on `main` matches that number — see `scripts/release.sh`.
Consumers can check whether their install is current with `scripts/check-latest.sh`.

## [Unreleased]

### Added
- Versioning system: `scripts/release.sh` (tag + GitHub Release driven off
  `plugin.json`), `scripts/check-latest.sh` (consumer freshness check), a
  `VERSION` marker stamped into claude.ai zips, and this changelog.

## [0.1.0] - 2026-06-19

### Added
- Baseline release. `stone-*` skill pack: `stone-commit`, `stone-merge`,
  `stone-promote-settings`, `stone-ai-sniff-test`, `stone-client-report`,
  `stone-journal`, `stone-journal-status`.
- Cross-surface install paths: `npx skills add`, Claude Code plugin marketplace,
  claude.ai zip upload.
- Nightly auto-journaling sweep (`scripts/journal-sweep.sh`) with launchd
  install/uninstall/run helpers.

[Unreleased]: https://github.com/stonematt/stonematt-skills/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/stonematt/stonematt-skills/releases/tag/v0.1.0
