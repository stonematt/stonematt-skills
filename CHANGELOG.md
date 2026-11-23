# Changelog

All notable changes to this skill pack are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the pack is
versioned with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The canonical version number lives in `.claude-plugin/plugin.json`. Each release
tag (`vMAJOR.MINOR.PATCH`) on `main` matches that number — see `scripts/release.sh`.
Consumers can check whether their install is current with `scripts/check-latest.sh`.

## [Unreleased]

## [0.6.0] - 2026-11-23

### Added
- `stone-merge` allows an admin bypass only when CI is unavailable, with local
  gates run and recorded on the PR first. (#177)

### Changed
- `stone-merge` is split by reader: `SKILL.md` for the dispatcher, `AGENT.md` for
  the merging agent and `PROMOTE.md` for promotion. The skill no longer force
  pushes. (#180)
- `stone-commit` is cut to its intent, with the PR steps split out. (#179)

### Fixed
- `stone-merge` routes CI-unavailable runs to step 2e and hands the bypass to the
  main session. (#178)

## [0.5.1] - 2026-11-23

### Fixed
- `swarm` can close a ticket that turns out already done with no PR. The
  orchestrator writes `#<n> → closed: <why>` on the lane's `Merged:` line, the
  console counts that ticket as landed, and an escalation stays open until the
  run log records how it ended. The `swarm-board` mod treats a ticked lane as
  done whatever its link's last status line says. (#151)
- `swarm-console` shows a run resumed into a new session as one run, with the
  orchestrator's calls counted once, and finds its run log by either session
  id. The Goal panel shows the run log's title and scope as soon as the title
  is written. (#130)

## [0.5.0] - 2026-11-23

### Added
- `release-manager` skill (**preview**, in `skills/in-progress/`). Takes one
  release from the product lead at the deploy rung and carries it to production
  verified and the spec closed. It keeps a ledger issue that it reads again on
  every wake, dispatches each thread of work as its own session from one brief
  template, keeps the merges and the release-head check in its own session,
  hands expected denials to Matt as `!` commands, and ends on a retro whose
  lessons go to the product lead's lessons file.
- `swarm-board` mod (**preview**, in `skills/in-progress/`). A Claude Code
  plugin with a hooks module, not a skill: one row per active swarm above the
  prompt of any session in the repo, with the swarm's goal, lanes done, lanes
  running, and a flag for each lane that needs you or has stalled.
  `/swarm-board` opens a pane with one line per lane. It reads the files the
  swarm console reads and writes nothing. Linked into `~/.claude/skills/` by
  hand, like the other previews.
- `product-lead` skill (**preview**, in `skills/in-progress/`). One product lead
  per product repo, from one shared skill. It infers each initiative's rung on
  the ask-matt ladder from the GitHub containers and live sessions, names the
  next move, convenes a per-project panel of reviewer personas, flags an
  architecture review on git drift, and writes one status page per project to
  the vault for the director. Setup writes the product brief, the panel and a
  lessons file, and installs the Graphify `post-merge` hook. Lessons about the
  skill itself go to its local workbench ledger.
### Changed
- `product-lead` and `release-manager` report `[skill]` lessons to a local
  workbench ledger, `~/.claude/skill-workbench/<skill>/feedback.md`, in place
  of comments on the public issue #137. Private-repo detail now stays on the
  operator's machine.
- `product-lead` folds its most recurrent lessons. Setup tracks the Graphify
  hook through `core.hooksPath` and drafts the panel as a full roster, of which
  a review seats three or four. Status asks whether each QA or UAT initiative is
  in or out of the release, traces printed numbers to their source, and logs
  scope calls as Waits-on-Matt lines with a default. Each open thread gets a
  named close-out owner.
- `release-manager` folds its most recurrent lessons. It keeps the host awake
  on overnight releases, leaves the ledger complete before it goes idle, checks
  a brief is non-empty before dispatch, puts gate risks in front of Matt with a
  default, and closes with one branch-delete command. Session briefs stop their
  own servers, and fall back to a ledger comment when the report address does
  not resolve.
- `swarm` folds the lessons that recurred most in its workbench ledger. The
  orchestrator checks tickets against the base before launch, writes the
  shared lane brief to a file once, checks that a PR is fresh before it merges,
  keeps the goal branch current with its base, and runs the whole-run review
  before the cleanup lane. Lanes stop force-pushing after the first push, clear
  only what the merge left in step g, and send `ready-to-merge` only after
  review with every criterion met. A wait on the owner is now written to the
  run log as `Waiting on owner:`, and in a goal swarm it is commented on the
  goal PR.
- `swarm-console` shows each `Waiting on owner:` line at the top of its
  Needs you bay.

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

[Unreleased]: https://github.com/stonematt/stonematt-skills/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/stonematt/stonematt-skills/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/stonematt/stonematt-skills/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/stonematt/stonematt-skills/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/stonematt/stonematt-skills/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/stonematt/stonematt-skills/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/stonematt/stonematt-skills/releases/tag/v0.1.0
