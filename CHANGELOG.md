# Changelog

All notable changes to this skill pack are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the pack is
versioned with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The canonical version number lives in `.claude-plugin/plugin.json`. Each release
tag (`vMAJOR.MINOR.PATCH`) on `main` matches that number — see `scripts/release.sh`.
Consumers can check whether their install is current with `scripts/check-latest.sh`.

## [Unreleased]

## [0.4.0] - 2026-10-05

Four skills in the pack manifest change in this release: `obsidian-quick-capture`
joins it, and `stone-merge`, `stone-commit` and `stone-ai-sniff-test` change.
The swarm skills below are previews and do not reach a `npx skills add` /
marketplace install.

### Added
- `obsidian-quick-capture` joins the pack (promoted from `skills/in-progress/`).
  It drops a note into a vault's `0.inbox/` in one `obsidian` CLI call, with
  minimal frontmatter, and captures to the vault the user names.
- `stone-merge` logs every run to a cross-repo JSONL through a new `log-run.sh`,
  including promotions. It warns on incomplete log calls instead of writing
  them silently.
- `stone-ai-sniff-test` flags the passive-projection opener ("Spent the
  weekend...", "Wrote up...") as a format-trap tell. (#47)
- `swarm` skill (**preview**, in `skills/in-progress/`). Lands a ticket queue
  unattended with file-fenced lanes of agents. Each lane runs as a chain of
  fresh agents, one per ticket, and the orchestrator runs every merge.
- `swarm-console` skill (**preview**, in `skills/in-progress/`). A local browser
  console over a swarm's own transcripts: a board of lanes by stage (Queued,
  Setup, Build, Review, PR / CI, Merged), a **Needs you** notice layer, a
  heartbeat per agent, a force graph and a lane timeline. Follows a live swarm
  or replays a past one. Read-only.
- `bse-monitor` skill (**preview**, in `skills/in-progress/`). A user-invoked
  watch that lands ready BSEs through a fresh subagent each.

### Changed
- `stone-merge` keeps `gh pr merge` in the main session and delegates the
  reversible work around it: the CI wait, log triage and the bookkeeping tail.
  The auto-mode classifier blocks that merge call from a subagent, so the skill
  is cut on that seam and names the resume path when a release merge is denied.
- `stone-merge` tiers its review gate, names the reviewer in the review policy,
  drops GSD state and stops offering production promotion unprompted. The
  `stone-merge-c` canary is folded back into the skill.
- The `stone-` prefix is now a convention for names likely to collide, such as
  common verbs, not a rule for every shipped skill (ADR-0004).

### Fixed
- `stone-merge` passes `--subject`, so merge commit titles keep the PR title.
- `stone-merge` prunes the stale `origin` ref after deleting a branch, and
  checks that it went.
- `stone-merge` separates transient classifier errors from content blocks.
- `stone-commit` refreshes the knowledge graph only where `graphify-out/` is
  tracked, not wherever it exists.

### Internal
- The plist test passes once the user opts in.
- The validation gate no longer fails a shipped skill with a bare name.

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

[Unreleased]: https://github.com/stonematt/stonematt-skills/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/stonematt/stonematt-skills/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/stonematt/stonematt-skills/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/stonematt/stonematt-skills/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/stonematt/stonematt-skills/releases/tag/v0.1.0
