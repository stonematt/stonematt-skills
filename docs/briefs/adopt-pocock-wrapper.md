# Adopt-Pocock Wrapper — Spec

Finalized spec for `stone-adopt-pocock`: a manually-run, rare, context-quiet skill
that adopts (installs **or** upgrades) Matt Stone's standing Matt-Pocock skill-suite
setup on any repo, in one invocation, leaving no straggling tasks. **It runs Matt
Pocock's own `setup-matt-pocock-skills` and overlays Matt Stone's conventions on top
— it never re-implements his spine.**

Charted by wayfinder map [#31](https://github.com/stonematt/stonematt-skills/issues/31);
build tracked by [#49](https://github.com/stonematt/stonematt-skills/issues/49).
Primary-source friction assets live in [`docs/wayfinder/adopt-pocock/`](../wayfinder/adopt-pocock/).

> **This revision supersedes the prior brief.** The prior shape — a deterministic
> ~2,100-line bash suite (`pocock-plan/apply/bind/member/migrant/preflight`) that
> re-implemented Pocock's spine and hardcoded a v1.0→v1.1 role-slug table — is
> **demolished** (see [Out of Scope: kill list](#out-of-scope)). It inverted the
> founding intent (*wrap not fork*, *trust live agent reasoning over a hardcoded
> map*), overfit to the 1.0→1.1 migration, and refused migrant repos outright. This
> spec restores the LLM-led shape and reduces the bash surface to a single helper.

## Problem Statement

Matt runs a spread of repos — the last four months land in *every* starting
position imaginable: fresh repos with no config, repos carrying Pocock v1.0 config,
partially-wired repos with a provisional banner, trackerless local corpora. Matt
Pocock's skill suite bumps versions with changes neither Matt has seen in advance.

Matt wants to walk up to **any** of these repos, invoke one skill, and have the repo
end up fully adopted to the current suite — install if fresh, upgrade if not —
**with nothing left over for him to do by hand**. The skill must figure out which
path it's on and finish the job. It must not overfit to today's version delta,
because the whole point is durability across the *next*, unseen bump. And it must
*leverage* Pocock's process, not reproduce or fork it.

The prior build failed this: it re-created Pocock's spine in bash (so a v2 change
means chasing it in scripts), hardcoded the role bindings as a slug table (one
rename breaks it), classified repos with filesystem heuristics (brittle), and only
handled greenfield (migrant refused). Competent code, wrong shape.

## Solution

A single manual skill, **`stone-adopt-pocock`** (`disableModelInvocation: true`),
that is **LLM-led with bash only as hands**:

1. **Preflight** — a read-only readiness gate. Inspect the environment; on any
   unmet precondition, halt with the exact copy-paste fix and stop. Never mutate the
   user's machine or credentials.
2. **Run `setup-matt-pocock-skills`** — Pocock's own install/reconcile owns the
   suite spine. Trust its output; never re-create it. Idempotent, so it covers both
   install and upgrade of *his* half.
3. **Present the directive** — the model audits the repo (by reading, not bash
   probing), consults its local workbench of prior adoptions, and declares this
   repo's **goal + per-project success criteria + detected contextual slots +
   planned Stone-delta mutations**. One go/no-go checkpoint.
4. **Overlay the Stone delta only** — the seam between Pocock's way and Matt's:
   translation-table conventions, the durable version stamp with a **live-discovered
   binding recipe** (the model reads the installed suite; no slug table), workbench-
   informed slot choices, a full stale-v1.0-prose rewrite of the wrapping layer, and
   (optionally, prompted) the board projection. Install-vs-upgrade dissolves — both
   run one idempotent delta-reconcile path that backfills what's missing and clobbers
   nothing the human authored.
5. **Behavioral smoke** — create a throwaway issue, move it across lanes, close it,
   confirm the board reflects the progression. The anti-silent-success gate.
6. **Verify + report + append the workbench** — check the declared criteria, report,
   and record what was proposed / corrected / surprised into the local learning
   ledger for the next run and the next suite version.

The result is a *small* skill: Pocock's setup does the heavy suite wiring; the
wrapper owns only the thin durable layer on top. When the suite hits v2, Matt
inherits Pocock's changes for free and the model reasons about the delta from its
workbench of precedent — not from a stale bash table.

## User Stories

1. As Matt, I want to invoke one skill on any repo and have it adopt the current
   Pocock suite, so that I never hand-migrate a repo again.
2. As Matt, I want the skill to detect whether this is an install or an upgrade and
   do the right one, so that I don't have to tell it which path it's on.
3. As Matt, I want the skill to leave zero straggling tasks, so that "adopted" means
   the system is actually ready to run, not "mostly wired."
4. As Matt, I want the skill to run Pocock's own `setup-matt-pocock-skills` first, so
   that his suite is wired his way and I only maintain the thin layer on top.
5. As Matt, I want the skill to never re-implement Pocock's spine, so that a future
   suite version doesn't force me to chase his changes in my own scripts.
6. As Matt, I want role bindings discovered live by the model reading the installed
   suite, so that a single skill rename in a bump doesn't silently break my config.
7. As Matt, I want repo classification done by the model reading the repo, not by
   directory heuristics, so that unusual repos aren't misclassified by a brittle
   probe.
8. As Matt, I want a read-only preflight that halts on a missing precondition with
   the exact fix, so that I fix one thing in my own shell and re-invoke, rather than
   the skill silently degrading or half-running.
9. As Matt, I want preflight to never touch my machine's auth or credentials, so that
   scope/PAT changes stay deliberate and in my own shell history.
10. As Matt, I want a single go/no-go checkpoint after the skill presents its plan,
    so that I can review durable config before it's written without approving each
    mutation one at a time.
11. As Matt, I want the skill to declare per-repo success criteria up front, so that
    "done" has an explicit, checkable meaning for this specific repo.
12. As Matt, I want the skill to verify its own work against those criteria, so that
    I trust the outcome without re-auditing by hand.
13. As Matt, I want a behavioral smoke that drives a real issue across the board, so
    that I know the system *runs*, not just that files exist (the genesis breakage:
    a suite skill silently succeeded on an unwired repo).
14. As Matt, I want the smoke to create and clean up a throwaway issue, so that the
    proof-of-wiring doesn't litter my tracker.
15. As Matt, I want the skill to keep a local workbench of every adoption run, so that
    later runs propose better and the skill learns from itself.
16. As Matt, I want the workbench gitignored and local, so that each install grows its
    own and no private-repo detail is ever pushed to the public skills repo.
17. As Matt, I want the workbench read before each audit and appended after, so that
    the next repo benefits from what the last one taught the skill.
18. As Matt, I want the workbench to be the durability engine for the unseen v2, so
    that when the suite changes in ways neither of us predicted, the model reasons
    from precedent instead of a hardcoded map.
19. As Matt, I want the skill to ask once, early, whether I want a real GitHub Projects
    board, so that the board is a deliberate opt-in, not an assumption.
20. As Matt, I want to be told at that moment if `gh` lacks `project` scope, with the
    exact `gh auth refresh` command, so that a missing scope is a front-loaded fix,
    not a mid-run surprise.
21. As Matt, when I opt into the board, I want it created and backfilled live by the
    skill using my own `gh`, so that it works day one.
22. As Matt, I want the CI sync workflows written regardless, dormant until the
    `PROJECT_TOKEN` secret exists and they reach `main`, so that the plumbing is all
    present and "auto-sync later" is a note, never a blocker.
23. As Matt, I want the un-deletable Projects v2 Status field handled correctly
    (overwrite-in-place, capture field + option ids), so that the fiddliest board
    step doesn't break.
24. As Matt, I want the board GraphQL handled by a deterministic helper the model
    calls, not freehanded, so that a wrong mutation can't corrupt the board.
25. As Matt, I want the skill to reconcile a partially-wired or provisional-banner
    repo without clobbering my hand edits, so that an upgrade backfills rather than
    overwrites.
26. As Matt, I want stale v1.0 skill references in my wrapping layer
    (`CLAUDE.md`/`WORKFLOW.md`, command maps, conventions) rewritten to the current
    contracts, so that no old-shape invocation runs silently under a new name.
27. As Matt, I want the skill to stop and surface an ambiguous or vanished role bind
    with what it found, so that durable config later sessions trust never carries a
    guessed bind.
28. As Matt, I want forked commit/merge skills flagged, never auto-rewritten, so that
    my customizations stay a human call.
29. As Matt, I want a trackerless local corpus (`facts/ + sources/ + refs/`) adopted
    without forced tracker machinery, so that a corpus-is-the-artifact repo gets the
    domain doc and stamp but no labels or board.
30. As Matt, I want a durable version stamp recording the suite version and binding
    recipe, so that a future run can tell current from drifted at a glance.
31. As Matt, I want the skill to assume a capable (Opus-class) processor for its
    reasoning, but to hard-gate on the presence + smoke evals, so that a weaker model
    can't silently ship a bad adoption.
32. As Matt, I want the skill to stay `disableModelInvocation: true` and manual, so
    that it never auto-fires and bloats an everyday session.
33. As a future maintainer, I want the bash surface reduced to one board helper, so
    that the skill is legible and portable and the model owns all the judgment.
34. As a downstream user who installs this skill, I want it to grow its own local
    workbench on my machine, so that it adapts to my repos without shipping me Matt's.

## Implementation Decisions

- **Deliverable = one skill, LLM-led executor.** `stone-adopt-pocock`,
  `disableModelInvocation: true`, manual, rare, context-quiet. It wires the repo in
  the same run (bias to action), not a generator that emits a plan for later.
- **Division of labor = LLM-led, bash-as-hands.** The model does all detection and
  role-binding by *reading* the repo and the installed suite. Scripts survive only
  for deterministic, error-prone mutations. No detection heuristics, no slug table.
- **Step one is invoking `setup-matt-pocock-skills`.** The wrapper *calls* Pocock's
  setup for the suite-config seam and trusts its output (trust-then-verify via the
  end smoke). It never reproduces the `docs/agents/*` spine or the label set that his
  setup owns. This is "wrap, never fork" made literal.
- **The Stone delta is the only thing the wrapper authors:** the translation-table
  conventions (canonical role → board expression), `docs/agents/pocock-stamp.md`
  (suite version + live-discovered binding recipe), workbench-informed contextual
  slots, the stale-v1.0-prose rewrite of the wrapping layer, and the optional board
  projection.
- **Install-vs-upgrade dissolves into one idempotent delta-reconcile.** Pocock's
  setup and the Stone delta are both idempotent; "greenfield" is just the special
  case where the delta is "everything." Reconcile the delta, backfill the missing,
  clobber nothing the human authored. No separate migrant/greenfield code paths.
- **Role binding is model-discovered live**, in order of authority: release
  notes/changelog → installed `SKILL.md` text (semantic contract match) → `ask-matt`
  router. Ambiguous (split) or empty (vanished) → **stop and surface**, never guess.
  Forked commit/merge skills → **flag, never auto-rewrite**. Scope is narrow —
  tracker-touching roles only.
- **Preflight is a read-only readiness gate.** Inspect `gh` auth + `project` scope,
  suite installed at `~/.agents/skills`, origin remote, current repo state. Any gap →
  halt with the exact copy-paste fix; the user runs it and re-invokes. Preflight
  **never mutates the user's machine or credentials** (no auto `gh auth refresh`).
- **One approval checkpoint.** After preflight passes and Pocock's setup runs, the
  model presents the directive (goal + criteria + detected slots + planned mutations)
  for a single go/no-go, then runs autonomously to done, re-surfacing only on a true
  blocker (ambiguous bind, credential wall).
- **The board is an early, explicit opt-in.** One question near preflight: real
  GitHub Projects board, or label-only? Label-only is the portable default and a
  complete config. On opt-in, if `gh` lacks `project` scope, that surfaces at
  preflight with the `gh auth refresh -s project` command.
- **Credentials are never silent stragglers.** `gh auth refresh -s project` (user's
  shell, if board wanted) is a preflight fix, not skill-run. `PROJECT_TOKEN` (repo
  secret, `project` write — `GITHUB_TOKEN` can't write user Projects v2) is required
  only by the CI sync workflows; the skill *writes those workflows regardless*, and
  they stay dormant until the secret exists AND they reach `main` via `dev→main`. The
  board is live + backfilled at run time by the skill's own `gh`; CI takes over later.
- **Board mutation stays a deterministic helper.** The one surviving script wraps the
  Projects v2 GraphQL gotchas: overwrite the un-deletable built-in Status single-select
  in place (`updateProjectV2Field`), capture field + option ids for the sync, and
  backfill existing issues (`addProjectV2ItemById` + `updateProjectV2ItemFieldValue`).
  The model calls it; it never freehands GraphQL.
- **Trackerless-local corpus** (`facts/ + sources/ + refs/` all present) is adopted
  without tracker machinery: domain doc + stamp + a corpus-flavored `## Agent skills`
  block; no `issue-tracker.md`/`triage-labels.md`, no labels, no board.
- **Translation-table invariants carry forward:** `needs-triage`→`status: triage`;
  `needs-info` an orthogonal facet, not a lane; `ready-for-agent`→`status: ready` +
  the `afk` flag; `ready-for-human`→`status: ready` (no flag); `Released` is
  label-less (the closed state). Skills apply the mapping and never learn column
  names; divergence is free while the mapping stays lossless. (Note the host repo's
  own tracker uses `afk-ready`; the wrapper's canonical flag is `afk` — the mapping
  is per-repo, not identity.)
- **The workbench (v2-durability engine):** central to `stonematt-skills`,
  **gitignored, local-only**. Layout mirrors the auto-memory index+siblings pattern —
  `workbench/INDEX.md` (one line per run) + `workbench/<date>-<slug>.md` siblings with
  YAML frontmatter (`suite_version`, `repo_kind`, `corrections_count`, `unresolved`)
  and a prose body (what was proposed, what the human corrected and why, what
  surprised the model). Read-before-audit, append-after. Full-fidelity local — no
  sanitization burden because it is never pushed; each install grows its own.
- **Model assumption:** the skill assumes an Opus-class processor for the audit/bind
  reasoning. Degradation is safe because the presence + smoke evals hard-gate — a
  weaker model cannot silently ship a bad bind.
- **Location:** stays `skills/in-progress/stone-adopt-pocock/` until it runs clean on
  3–4 real repos, then promotes out of in-progress.

## Testing Decisions

Good tests here assert **external behavior and outcomes**, never the model's internal
reasoning. Detection and binding are model judgment now — they are proven by the
adoption *outcome*, not by golden files (which is why the prior detection goldens are
deleted, not ported). Two seams, highest-possible, fewest-possible:

- **Seam 1 — runtime acceptance gate (integration, primary, highest).** One seam over
  the whole skill run. After adoption, assert the declared success criteria hold:
  the spine present (or the corpus subset), the `## Agent skills` block, the canonical
  labels created (or `[]` for a corpus), the version stamp written, no lingering v1.0
  references, no provisional banner, all tracker-touching roles bound. **Plus the
  behavioral smoke:** create a throwaway issue, move it across lanes, close it, and
  confirm the board reflects the progression — then clean the issue up. This is the
  anti-silent-success gate (brief line: *"the map built successfully" is not proof of
  correct wiring*). It exercises the LLM-led half by outcome. Built as
  `tests/pocock-acceptance-gate.sh` (#66) — grown from and superseding the held-out
  e2e smoke seed (#59): Part A asserts the criteria against the adopted repo, Part B
  drives the throwaway-issue smoke. Offline-safe by default (self-verifies against
  fixtures + a fake-`gh` shim); the live smoke is gated behind `POCOCK_SMOKE_LIVE=1`.
- **Seam 2 — board GraphQL helper (unit, offline).** The one surviving script:
  deterministic input → correct GraphQL/mutation output (Status-field overwrite, field
  + option id capture, backfill payloads). Fixture-tested, no network. Prior art: the
  `gh-*-shim` fakes and `tests/test-pocock-board.sh` in the current suite are the
  starting point — kept and refocused on just the helper.

No golden-file detection tests. No per-mode (migrant/greenfield) unit seams — the
modes dissolved into one idempotent path, tested through Seam 1. The
`setup-matt-pocock-skills` invocation is Pocock's seam, not ours; it is trusted and
verified transitively through Seam 1's smoke.

## Out of Scope

**Kill list (the negative delta — must happen as part of this build):**

- Delete `scripts/pocock-plan.sh` (detection heuristics → model reads).
- Delete `scripts/pocock-bind.sh` (the forbidden slug table → live binding).
- Delete `scripts/pocock-apply.sh` (re-implements Pocock's spine → his setup owns it).
- Delete `scripts/pocock-member.sh` (classification → model reasoning).
- Delete `scripts/pocock-migrant.sh` (migrant branch → dissolved idempotent path).
- Delete `scripts/pocock-preflight.sh` (preflight is now read-only model inspection).
- Delete the detection goldens `tests/golden/pocock-*.{json,yaml,md}` and the
  per-script tests `tests/test-pocock-{plan,bind,apply,member,migrant,slots,trackerless}.sh`.
- Refactor `scripts/pocock-board.sh` down to the single board/GraphQL helper the model
  calls (keep, don't delete). Optionally fold a tiny idempotent `gh label` creator in.

Net: ~2,100 lines of bash → ~300.

**Genuinely out of scope:**

- Building the `SKILL.md` itself — that is the `/write-a-skill` session that consumes
  this spec (tracked by #49).
- Modifying anything Pocock's `setup-matt-pocock-skills` owns — the wrapper calls it,
  never edits it.
- Standing up a multi-repo org (governance + `.github` mechanics repos) — the wrapper
  configures a repo to *join* an existing org board; standing up the org is a one-time
  human act. The board helper never scaffolds the org.
- Auto-provisioning credentials — `gh auth refresh` and `PROJECT_TOKEN` are the user's
  deliberate acts; the skill surfaces the exact commands and stops.
- Sanitizing the workbench for publication — it is gitignored and local; distilling
  sanitized *patterns* into committed skill prose is a later, deliberate act.

## Further Notes

**Founding decisions that still hold** (carried from the prior brief, re-grounded):
wrap-never-fork (now literal: *call* his setup); fixed spine (Pocock's setup output)
vs contextual slots (the Stone delta the model reasons about); translation-table
decoupling; stop-and-surface on ambiguous/empty binds and forked commit/merge skills;
two orthogonal `afk` axes (kanban `status:*`+`afk`, wayfinder `wayfinder:*`) coexist.

**Why the demolition is justified** (the reasoning behind deleting 2,100 lines lives
in the grilling session, Q1–Q14): the prior build re-implemented Pocock's spine
instead of calling his setup, hardcoded the exact "slug-name table that breaks on
rename" the founding brief forbade (its alternates were literally the v1.0 names —
overfit confirmed in code), classified repos with `[ -d ]` filesystem probes, and
left the durability value-prop (migrant mode) unbuilt (apply refused migrant, exit 3).
Competent deterministic 1.0→1.1 migration tooling, mislabeled as the adopt skill.

**Next step:** `/write-a-skill` (with `/writing-great-skills` as the quality lens) to
author the `SKILL.md` from this spec — a short, optimized skill, since Pocock's setup
carries the heavy wiring and the wrapper owns only the seam between his way and Matt's.
