# Adopt-Pocock Wrapper — Skill Spec

Finalized spec for a manually-run, rare, context-quiet Claude Code skill that configures a repo to Matt Stone's standing Pocock-suite setup and keeps it durable across Matt Pocock's version bumps. The skill reads Matt Pocock's *currently-installed* skill suite, audits the repo's state (greenfield / migrant / current), reconciles it against Matt's canonical config (Kanban spine, triage roles, eligibility flags, intent/area slots), and writes durable per-repo config. **It wraps the suite; it never forks it.** This document is the handoff to a future `/write-a-skill` build session — it stops at the spec; no build here.

Charted by wayfinder map [#31](https://github.com/stonematt/stonematt-skills/issues/31). Resolved-ticket detail and primary-source friction assets live in [`docs/wayfinder/adopt-pocock/`](../wayfinder/adopt-pocock/).

## The skill

- **Role:** the *setup/precondition* role of the suite — the enhancement of `/setup-matt-pocock-skills` with an **upgrade mode** (genesis product ask, [#45](https://github.com/stonematt/stonematt-skills/issues/45)). Whether it ships as a new sibling skill or as new modes of `setup-matt-pocock-skills` is a build-time naming call (see Open questions).
- **Invocation:** manual only. `disableModelInvocation: true` — the model never auto-fires it; a human runs it on a version bump or when onboarding a repo.
- **Cadence:** rare (a version bump, or first wiring of a repo) and **context-quiet** — it should not bloat everyday sessions.
- **Modes (all one skill):** *greenfield* scaffold · *migrant* upgrade · *current* patch. Mode is detected, not asked (see State detection).

## Founding decisions (settled while charting — fixed inputs, not open)

1. **Wrap, never fork.** Durability across Matt's versions is the whole point.
2. **Deliverable = one skill**, manual & rare.
3. **Nitimini is canonical** config; other boards are a *flex-point catalog*, not co-equal models.
4. **Intention-led abstraction** — a FIXED SPINE (board, statuses, progression, eligibility) vs CONTEXTUAL SLOTS (intent values, area values, source-of-truth seam) filled per-project by the running agent.
5. **Durability = role-binding** (bind Matt's current skills to abstract roles) **+ a recorded Matt-version stamp** per run for diff-based audit.
6. **Translation-table decoupling** — Matt's canonical roles/labels are a *translation table onto the project's richer board vocabulary, independent of it*. Skills apply the mapping and never learn column names. Divergence is free as long as the mapping is lossless. This is how wrap-not-fork works for vocabulary.
7. **Executor is an orthogonal facet, not a lane** — `afk` is a status-independent label; kanban (`status:*` + `afk`) and wayfinder (`wayfinder:<type>` + `wayfinder:afk`) are two coexisting axes, same concept, no collision.

## Preflight wiring gate (hard requirement)

A Pocock skill — `/wayfinder` especially — will **silently run on an unwired repo and appear to succeed** ([#45](https://github.com/stonematt/stonematt-skills/issues/45), genesis breakage). "The map built successfully" is **not** proof of correct wiring. So the wrapper's first act is a preflight check:

- Does `docs/agents/issue-tracker.md` exist, and is it **reconciled** (no "provisional / not reconciled" banner)?
- Are the canonical roles **bound** to real labels (not left at seed identity defaults)?
- Are `docs/agents/triage-labels.md` and `docs/agents/domain.md` present?
- Any **stale references** to renamed/removed v1.0 skills in the wrapping layer?

On any miss: reconcile config **first** (setup-reconcile), **then** audit the wrapping layer — **never audit-only** (audit-only misses the config seam entirely).

## Config model — fixed spine + contextual slots

### Constant spine (must NOT vary)

- `docs/agents/{domain,issue-tracker,triage-labels}.md` trio + the CLAUDE.md `## Agent skills` block.
- GitHub Issues via `gh`; PRDs/briefs in-repo (`docs/briefs/`), not as issues.
- Board state machine: `triage → ready → wip → staged → Released`, with `blocked` as a side state.
- Triage core: `status:*` lifecycle + orthogonal facets (`afk`, `needs-info`); the wayfinder shape.
- `Released` is **label-less** (nitimini invariant): in label-only mode it is the issue's `closed` state; where a board exists, `Status=Released` is just the projection of closed.

### Contextual slots (agent varies, per repo, detect-then-confirm)

**Code-vs-docs axis:**
- **R1 — source-of-truth declaration:** in-repo vs external vault / `contracts/`+ADRs / `facts/` corpus. Cross-seam links are one-way when the SoT is external.
- **R2 — lifecycle overlay:** optional. Full `status:*` kanban / flat / identity — not hardcoded.
- **R3 — idea→issue gate:** governance/docs repos forbid `to-tickets` on raw ideas (ADR/spec first).
- **R4 — PRs-as-request-surface:** boolean, default `no`.
- **R5 — area labels:** content-defined; **default empty, emergent** — never fabricate a taxonomy.

**Single-vs-multi-repo axis:**
- **R6 — board scope:** `own` vs `shared org Project`.
- **R7 — project-sync plumbing** + a documented per-repo `PROJECT_TOKEN` PAT.
- **R8 — no per-repo Milestones in shared mode:** ROADMAP → board Epics; use built-in Repository + Parent/Sub-issue fields.
- **R9 — governance/mechanics split** as a documented rule (not a copyable file set).

**Intent slot:** seed for the repo's kind. For a skills/docs repo: `intent:{structural, voice, capability}` — each selects a different review/acceptance lens (`structural` = refactor no-behavior-change; `voice` = prose/persona, snapshot diff IS the review; `capability` = new behavior, acceptance = behavior test).

**How the agent lands on slots — detect-then-confirm:** inspect (file mix, presence of vault/`contracts/`/`facts/`, `git remote`, shared org board) and **propose** the slot values ("docs repo, external SoT = vault, no kanban, member of org board X"); the dev confirms or corrects. Not a blank interview, not silent auto-config.

## Role-binding contract ([#35](https://github.com/stonematt/stonematt-skills/issues/35))

**Binding is LLM-discovered live, not a coded map.** No slash-name table (breaks on rename), no DAG-position matcher, no hand-maintained manifest. At run time the agent reads the *installed* suite and binds each abstract role to the skill that currently fills it, by semantic contract match.

**Discovery procedure — consult in order of authority:**
1. **Matt's release notes / changelog** (a bump usually announces the split/merge/rename outright).
2. **Installed `SKILL.md` text** — description + in/out contract, matched to the role's contract.
3. **`ask-matt`** — the router skill exists to answer "which skill fills this role"; engage when 1–2 are ambiguous.

**Roles bound (narrow — tracker-touching only):** on-ramp/decision (wayfinder, triage, diagnosing-bugs, improve-codebase-architecture) · spec (to-spec) · slice-to-tickets (to-tickets) · implement · review (code-review) · setup/precondition · wayfinder itself. **Not bound:** idea-sharpening, vocabulary-layer, investigation, session-crossing, flow/ask router, learning.

**Guardrail — stop and surface:** on an ambiguous or empty bind (a role that split, merged, or vanished), the agent **stops and surfaces to the human** with what it found. No silent auto-bind — this wrapper writes durable config that later sessions trust; a bad bind must not propagate. **Forked commit/merge skills stay a human call** — flag, never auto-rewrite.

**Cacheable, keyed by version:** discovered bindings + version delta cache as a per-version recipe (mechanism → #37).

**Philosophy — under-engineer on purpose.** Trust an improving process + live agent reasoning over a hardcoded map that a single rename would break.

## Translation table — the durability engine ([#43](https://github.com/stonematt/stonematt-skills/issues/43))

Matt's canonical triage roles map onto the project's richer board vocabulary, independent of it. A skill wanting a role applies the board expression and never learns column names:

| Canonical role (skills speak this) | Board expression (this repo) |
|---|---|
| `needs-triage` | `status: triage` |
| `needs-info` | `needs-info` (orthogonal facet) |
| `ready-for-agent` | `status: ready` **+** `afk` |
| `ready-for-human` | `status: ready` (no `afk`) |

- Flag is `afk`, **not** `afk-ready` (don't re-smuggle "ready" into a status-independent facet).
- **Two orthogonal afk axes coexist by design:** kanban (`status:*` + `afk`) and wayfinder (`wayfinder:<type>` + `wayfinder:afk`). Same concept, two scoped labels, no collision.
- The seed's **identity** default (`needs-triage`→`needs-triage`) is the **wrong** baseline for this fleet — binding must force an explicit per-repo map, never accept identity silently.
- Divergence is free as long as the mapping is **lossless**; the board may enrich with orthogonal facets (e.g. `needs-info` as a facet, not a 7th lane) without forking the spine.

## State detection + migrant scope ([#36](https://github.com/stonematt/stonematt-skills/issues/36))

**Detection = two orthogonal axes** (not a flat 4-way branch). Walk **substrate first**, then **freshness** within it.

- **Substrate** — does `git remote` have an origin?
  - *tracker-backed* — GitHub Issues present; `docs/agents/*` config applies.
  - *trackerless-local* — no remote; a `facts/ + sources/ + refs/` corpus is the artifact, no GitHub tracker.
- **Freshness:**
  - *greenfield* — no `docs/agents/`, no old slugs → scaffold fresh.
  - *migrant* — old slugs or a stale version-stamp → run migration.
  - *current* — config present, stamp == installed → patch only the user's overlay.

**Migrant-vs-current signal = both, layered:** the version-stamp (#37) is the fast path; a **slug-scan** for v1.0 names (`to-prd`, `to-issues`, `decision-mapping`, `review`) across WORKFLOW/CLAUDE/prose is the belt-and-suspenders that catches a repo migrated without a stamp. Partial config (some `docs/agents/` present, some missing) is a migrant sub-case: backfill the missing pieces; reconcile a "provisional" banner, don't clobber.

**Migrant scope = both halves, in order** (from #45 primary source):
1. **Config seam first** — reconcile the suite's own config (issue-tracker / triage-labels / domain docs) to the installed version.
2. **Then the wrapping layer** — full stale-ref **+ contract** rewrite of `WORKFLOW.md`, `CLAUDE.md`/`AGENTS.md` rules, `status:*` conventions, command maps, prose. Audit-only misses the config half; find-and-replace misses the *contract* changes (old shape runs silently under a new name).

**Fleet split:** carry the portable `status:*` label mapping to other repos, but **drop** the local wayfinder section — it is bespoke to a wayfinding repo.

## Version-stamp + drift audit ([#37](https://github.com/stonematt/stonematt-skills/issues/37))

One artifact unifies the version stamp, the #36 freshness fast-path, and the #35 role-binding recipe cache.

**Stamp — `docs/agents/pocock-stamp.md`** (markdown + YAML frontmatter; human-readable, machine-parses). Fields: `suite`, `version`, `stamped` date, `source: ~/.agents/skills` (canonical catalog — **not** the `~/.claude/skills` activated projection), a **light whole-catalog** map (name + `dmi` + `activated`, so drift flags any skill Matt ships/kills), and **full `bindings` only for the tracker-touching roles**.

**No content fingerprints.** Keyed on the **version string alone**. On any bump the agent re-reads `SKILL.md` live (#35 discovery) and judges drift itself — no stored hashes. The rare unbumped-contract-change case is covered by the #36 slug-scan + live re-read.

**Staleness rule:**
1. Read installed `version` from `~/.agents/skills`.
2. `installed == stamp` → **current**: trust cached `bindings`, skip re-discovery.
3. else → **migrant**: re-discover live (#35), emit drift report, run migrant flow (#36), overwrite the stamp with the new recipe.

**Drift report — `docs/agents/pocock-drift-<date>.md` + session echo.** Dated file (migration audit across ~a dozen repos is worth a record) and printed. Grouped: renamed/merged · **contract-changed** (the silent-breakage class, from the live re-read) · added · removed · bindings-shifted · stale-refs-in-wrapping-layer → hands to the migrant flow.

## Board / CI projection — optional, prompted ([#38](https://github.com/stonematt/stonematt-skills/issues/38), [#40](https://github.com/stonematt/stonematt-skills/issues/40))

**Portable default = label-only.** The spine that ports everywhere is the **label vocabulary + state machine**, not the CI machinery. The Project v2 board + `project-sync.yml` + `clean-status-on-close.yml` are a **flex point** — never a requirement. The config is valid and complete without them.

**End-of-run prompt:** after configuring, **ask** whether to also wire the CI workflows + Project board (optionally sharing an org board via PAT sync). Default leans yes — the dev usually wants glanceable visibility — but "docs/skills repo, no prod deploy" does **not** imply skip-the-board. Ask, don't assume. On a **member repo of an existing org board**, this prompt is the opt-out seam and is skipped (org plumbing already exists).

**Board-setup gotchas the wrapper must handle (from #40 hands-on audit):**
- **Status field is not pure `gh project`.** A fresh Project ships a built-in **Status** single-select that is **un-deletable** (`deleteProjectV2Field` → "Only custom fields can be deleted"). Overwrite its options in place via raw `gh api graphql updateProjectV2Field(input:{fieldId, singleSelectOptions:[…]})` — the mutation replaces the whole option set. Then **capture the field id + option ids** for the CI sync. This is the single fiddliest step.
- **Irreducible human secret step.** Project mutations need a PAT with `project` write; `GITHUB_TOKEN` cannot write user-owned Projects v2. The agent writes the YAML but **stops** and hands the human a precise `PROJECT_TOKEN` checklist (hardened variant = fine-grained PAT).
- **CI activation lags to the default branch.** `issues`-triggered workflows run from the default branch, so under `feature→dev→main` they are **dormant until the first `dev→main` release PR** lands them on `main`. Backfill of existing issues must therefore be **manual GraphQL** (`addProjectV2ItemById` + `updateProjectV2ItemFieldValue`), not lean on the fresh workflow.
- **Audit sweep for unlabelled issues.** An open issue with a live branch but no `status:*` label is invisible to the board — sweep and reconcile status from branch/PR state; don't assume every issue carries a lane.
- **Multi-repo:** on a member repo apply the **uniform spine incl. the same `status:*` vocabulary** (consistency is the point — this overrides a surveyed "flat, no kanban" state). Board/project automation is decoupled and per-member. The wrapper **never scaffolds the org itself**.

## Outputs (first-class artifacts, not just GitHub state)

- `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md` — written/updated. **The tracker agent-doc is a first-class output** — configuring isn't done when labels+board+CI exist; else every future session re-derives the spine from nitimini.
- `docs/agents/pocock-stamp.md` — version stamp + binding recipe.
- `docs/agents/pocock-drift-<date>.md` — on a migrant run.
- CLAUDE.md `## Agent skills` block, and (migrant) rewritten wrapping-layer prose/command maps.
- GitHub state: labels, and optionally the Project board + CI workflows + backfill.

## Guardrails (stop-and-surface points)

- Ambiguous/empty role bind → stop, surface findings, don't auto-bind.
- Forked commit/merge skills → flag, never auto-rewrite.
- `PROJECT_TOKEN` provisioning → emit checklist, stop for the human.
- Seed identity label-map → reject as a silent default; force an explicit per-repo map.
- Provisional/partial prior-run state → detect and reconcile, don't clobber or blindly trust.

## Out of scope

- Building the wrapper skill (this spec is the destination; build is a separate `/write-a-skill` session).
- Cold-installing / validating the wrapper on any repo.
- **Scaffolding a multi-repo org** (standing up governance + `.github` mechanics repos) — the wrapper configures a repo to *join* an existing org board; standing up the org is a human/one-time act.

## Open questions (for the build session)

- **Skill identity/name:** new sibling skill vs new `greenfield|migrant|current` modes on `setup-matt-pocock-skills`. The genesis framed it as giving setup an "upgrade mode"; the map framed a single "adopt-Pocock wrapper." Resolve at build time — the contract above holds either way.
