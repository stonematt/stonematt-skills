---
name: stone-adopt-pocock
description: Configure a repo to Matt Stone's standing Matt-Pocock skill-suite setup — the Kanban spine, triage roles, and per-repo agent docs — and keep it durable across Pocock version bumps. Manual only, rare, context-quiet. This is the greenfield skeleton (issue #51); migrant upgrade and current patch are later modes. Trigger only when a human explicitly runs /stone-adopt-pocock on a fresh or version-bumped repo.
disableModelInvocation: true
---

# Adopt-Pocock wrapper (greenfield skeleton)

Wire a repo to Matt Stone's standing Pocock-suite config: the `status:*` Kanban
spine, the canonical triage roles, the per-repo `docs/agents/*` trio, the CLAUDE.md
`## Agent skills` block, and a version stamp for later drift audits. **It wraps
the suite; it never forks it.**

Spec: [`docs/briefs/adopt-pocock-wrapper.md`](../../../docs/briefs/adopt-pocock-wrapper.md).

## When this runs

- **Manual only.** `disableModelInvocation: true` — the model never auto-fires
  this. A human runs it on a version bump or when onboarding a repo.
- **Rare and context-quiet** — it must not bloat everyday sessions.
- **This skeleton covers the greenfield mode only** (issue #51): a fresh repo with
  no `docs/agents/` config and no prior stamp. Migrant upgrade and current patch
  are later tickets; the apply step refuses (exit 3) on any non-greenfield repo
  rather than clobber existing config.

## Deliverable identity (resolved)

The brief left one open question: ship as a **new sibling skill** or as new
`greenfield|migrant|current` **modes on `setup-matt-pocock-skills`**. Resolved:
**new sibling skill, `stone-adopt-pocock`, in this repo.** Rationale:

- Founding decision #1 is **wrap, never fork.** `setup-matt-pocock-skills` is Matt
  Pocock's skill; adding modes to it would fork the suite we are trying to wrap.
- A sibling skill in `stonematt-skills` keeps Matt Stone's wrapper durable and
  versioned independently of Pocock's bumps — exactly the durability the brief wants.
- The three modes still live in **one skill** (this one), detected not asked; they
  are internal modes of `stone-adopt-pocock`, not modes bolted onto Pocock's setup.

It lives in `skills/in-progress/` while the migrant and current modes are still
being built.

## Workflow

### 1. Emit the plan (mutates nothing)

The deterministic plan-emitter inspects the repo and classifies it on two axes —
substrate (tracker-backed vs trackerless-local) and freshness (greenfield /
migrant / current) — emitting a JSON plan. It touches nothing.

```bash
bash scripts/pocock-plan.sh --dry-run --json --root .
```

Read the plan's `freshness`. **If it is not `greenfield`, stop** — this skeleton
does not handle migrant or current yet. Surface the classification to the human.

### 1.5 Resolve the contextual slots (detect-then-confirm)

The **fixed spine** (board, statuses, progression, eligibility) never varies. The
**contextual slots** do, per repo — and the wrapper fills them by *proposing from
inspection, then having the dev confirm or correct*. This is **not a blank
interview** (the plan already guessed every slot from the tree) and **not silent
auto-config** (the dev sees and can override every value before apply writes it).

The plan's `proposed_slots` block carries the proposal, all detected offline:

| Slot | Detected from | Proposed value(s) |
|---|---|---|
| `source_of_truth` | `vault/` · `contracts/` · `facts/` dir, else in-repo | `in-repo` / `vault` / `contracts` / `facts` |
| `lifecycle_overlay` | substrate — tracker-backed vs trackerless-local | `kanban` / `flat` / `identity` |
| `idea_to_issue_gate` | `docs/adr/` or `docs/briefs/` present | `open` / `spec-first` |
| `prs_as_request_surface` | default (no signal) | `false` (default no) |
| `intent` | repo-kind seed | `[structural, voice, capability]` |
| `area_labels` | **never fabricated** | `[]` — empty and emergent |

Read the proposal aloud to the dev as a single sentence — e.g. *"docs repo,
source-of-truth = vault, no kanban (flat), spec-first idea gate, PRs not a request
surface; area labels stay empty."* Then **ask the dev to confirm or correct**. On a
correction, carry the corrected value forward (the apply consumes the confirmed
slots, not the raw guess). Two hard rules:

- **`area:` defaults empty/emergent — never fabricated.** Do not invent a content
  taxonomy; area labels accrete from real work, not from a setup guess.
- The proposal is a **starting point, not a verdict.** A missing signal (e.g. no
  `vault/`) means the *default* was proposed, not that the dev has no say.

Precedence when several source-of-truth corpora coexist is deterministic
(`vault > contracts > facts`); if the guess is wrong, the dev corrects it here.

### 2. Apply the greenfield wiring

`pocock-apply.sh` consumes the plan and, on a greenfield repo, wires it:

```bash
bash scripts/pocock-apply.sh --root .
```

It performs, idempotently and without clobbering existing files:

1. Writes `docs/agents/{domain,issue-tracker,triage-labels}.md` — the constant
   spine. `triage-labels.md` carries the **static** canonical -> board translation
   table (below).
2. Adds the `## Agent skills` block to `CLAUDE.md` (creates the file if absent).
3. Writes `docs/agents/pocock-stamp.md` — the suite version + static translation
   table + the live-discovered role-binding recipe. When an installed suite is
   available (`POCOCK_SUITE_DIR`, default `~/.agents/skills`), `pocock-bind.sh`
   (#53) binds the tracker-touching roles from the suite and caches them into the
   stamp's `bindings:` block; with no suite, `bindings` is left `null`.
4. Creates the canonical labels via `gh label create` (the `status:*` lifecycle
   plus the orthogonal `afk` and `needs-info` facets).

Determinism knobs: `POCOCK_INSTALLED_VERSION` (recorded in the stamp),
`POCOCK_STAMP_DATE`, `POCOCK_GH` (label-creation command). Pass `--skip-labels`
to write the file artifacts without touching GitHub.

### 3. Confirm the repo is fully wired

Re-emit the plan; a wired repo no longer reads `greenfield`. The four label +
docs + stamp artifacts should all be present.

### 4. Offer the optional board / CI projection (prompted)

**Label-only is the portable default — the config is valid and complete without
any board.** After the label spine is wired, **ask** the human whether to also
project it onto a GitHub Projects v2 board + the sync CI. Default leans yes (a
glanceable board is usually wanted), but "docs/skills repo, no prod deploy" does
**not** imply skip — ask, don't assume. On a **member repo of an existing org
board** (`board_scope=shared`) this prompt is the opt-out seam and is skipped —
the org plumbing already exists.

```bash
# board_scope=own: emit the projection (workflows to stdout; add --write to save).
bash scripts/pocock-board.sh --root .            # review the projection + gotchas
bash scripts/pocock-board.sh --root . --write    # write the two workflow files

# member repo of an existing org board — the prompt is skipped:
bash scripts/pocock-board.sh --root . --board-scope shared
```

The projection handles the hands-on GitHub Projects gotchas (from the #40 audit):

1. **Un-deletable Status field.** A fresh Project's built-in Status single-select
   cannot be deleted (`deleteProjectV2Field` → "Only custom fields can be
   deleted"). The script emits a raw `gh api graphql updateProjectV2Field` that
   overwrites its options in place, and returns the field id + option ids to
   **capture** for the CI sync.
2. **`PROJECT_TOKEN` — human secret step. STOP.** Projects v2 mutations need a
   PAT with `project` write (`GITHUB_TOKEN` cannot write user-owned Projects v2).
   The script emits a precise `PROJECT_TOKEN` checklist and **stops** — provision
   the credential, then run the mutation + backfill.
3. **CI is dormant until the default branch.** `issues`-triggered workflows run
   from the default branch, so under `feature→dev→main` they stay dormant until
   the first `dev→main` release lands them on `main`. Backfill existing issues
   with **manual GraphQL** (`addProjectV2ItemById` + `updateProjectV2ItemFieldValue`),
   not the (dormant) workflow.
4. **Audit sweep.** An open issue with a live branch but no `status:*` label is
   invisible to the board — `pocock-board.sh --audit-sweep` reconciles a lane
   from branch/PR state before backfill.

## Multi-repo member mode (#58)

When the repo is a **member of a shared org board** (`board_scope=shared`) the
wrapper does **less, not more** — the org plumbing already exists. The plan
emitter proposes `board_scope=shared` when the origin remote's owner is one of
the shared orgs named in `POCOCK_SHARED_ORGS` (a space/colon-separated list); the
human confirms/overrides with `--board-scope`. `pocock-member.sh` computes the
member verdict:

```bash
# detected member (org owner in POCOCK_SHARED_ORGS), or forced with --board-scope:
POCOCK_SHARED_ORGS=my-org bash scripts/pocock-member.sh --root .
bash scripts/pocock-member.sh --root . --board-scope shared --json
```

- **Uniform spine, forced.** A member gets the **same `status:*` vocabulary**
  every member carries — consistency across the fleet is the point. That
  uniformity **overrides a surveyed `flat`/`identity` state**: on a member the
  lifecycle overlay is forced to `kanban` even if the survey (or a human
  correction) proposed flat. `--surveyed-overlay flat` shows the override
  (`spine_override: true`).
- **Board/CI prompt skipped.** The end-of-run board prompt is the opt-out seam
  and is skipped — the org's board + `project-sync` plumbing already exists
  per-org (same behavior as `pocock-board.sh --board-scope shared`).
- **Decoupled, per-member.** Board/project automation stays per-member and is
  **never templatized** across members; no per-repo Milestones in shared mode
  (brief R8 — ROADMAP → board Epics, built-in Repository + Parent/Sub-issue
  fields).
- **Never scaffolds the org.** Standing up the org's governance + `.github`
  mechanics repos is a human, one-time act — out of scope for the wrapper.

## Static translation table

The wrapper applies this mapping and never learns board column names. Divergence
is free as long as the mapping stays lossless.

| Canonical role (skills speak this) | Board expression |
|---|---|
| `needs-triage` | `status: triage` |
| `needs-info` | `needs-info` (orthogonal facet) |
| `ready-for-agent` | `status: ready` + `afk` |
| `ready-for-human` | `status: ready` (no `afk`) |

The flag is `afk`, **not** `afk-ready`. `needs-info` is an orthogonal facet, not
a seventh lane. `Released` is label-less — the issue's closed state.

## Live role-binding (#53)

Distinct from the translation table above (canonical role -> board expression),
role-binding maps each **tracker-touching abstract role** to the installed skill
that currently fills it. `pocock-bind.sh` discovers this live from the installed
suite rather than hardcoding a slug table that a single rename would break:

```bash
bash scripts/pocock-bind.sh --suite ~/.agents/skills
```

- **Authority order:** release notes / changelog -> installed `SKILL.md` text ->
  `ask-matt` (the router that answers "which skill fills this role").
- **Narrow scope** — only the tracker-touching roles are bound: `on-ramp`,
  `spec`, `slice-to-tickets`, `implement`, `review`, `setup`, `wayfinder`.
- **Stop-and-surface** — an ambiguous (split) or empty (vanished) bind exits 4
  and prints findings; no bind is written. Durable config later sessions trust
  must never carry a guessed bind.
- **Forked commit/merge skills** are flagged in the recipe, never auto-rewritten.
- The recipe (bindings + version delta) is **cached into the stamp** keyed by
  version. On the current suite it reproduces the static table (a pure expand).

## Guardrails

- **Greenfield only (this skeleton).** Never apply to a migrant or current repo —
  the apply refuses (exit 3) rather than clobber. Backfilling missing pieces and
  reconciling a provisional banner belong to the migrant mode.
- **Never fork the suite.** This skill wraps `setup-matt-pocock-skills`; it never
  edits or re-implements Pocock's skills.
- **Never hand-write role bindings.** `pocock-bind.sh` discovers them live from
  the installed suite; on an ambiguous/empty bind it stops and surfaces for a
  human rather than guessing.

## Out of scope (this skeleton)

- Migrant upgrade and current patch modes.
- Live role-binding discovery (#35).
- Standing up a multi-repo org — the wrapper configures a repo to *join* an org
  board; standing up the org is a one-time human act. The board projection
  (`pocock-board.sh`) never scaffolds the org itself.
