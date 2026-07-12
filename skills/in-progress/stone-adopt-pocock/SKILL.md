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
   table. `bindings` is left `null`; live role-binding discovery is deferred to
   the role-binding ticket (#35).
4. Creates the canonical labels via `gh label create` (the `status:*` lifecycle
   plus the orthogonal `afk` and `needs-info` facets).

Determinism knobs: `POCOCK_INSTALLED_VERSION` (recorded in the stamp),
`POCOCK_STAMP_DATE`, `POCOCK_GH` (label-creation command). Pass `--skip-labels`
to write the file artifacts without touching GitHub.

### 3. Confirm the repo is fully wired

Re-emit the plan; a wired repo no longer reads `greenfield`. The four label +
docs + stamp artifacts should all be present.

## Static translation table

The wrapper applies this mapping and never learns board column names. Divergence
is free as long as the mapping stays lossless. (Live discovery of Matt's currently
installed skills against abstract roles is deferred to the role-binding ticket.)

| Canonical role (skills speak this) | Board expression |
|---|---|
| `needs-triage` | `status: triage` |
| `needs-info` | `needs-info` (orthogonal facet) |
| `ready-for-agent` | `status: ready` + `afk` |
| `ready-for-human` | `status: ready` (no `afk`) |

The flag is `afk`, **not** `afk-ready`. `needs-info` is an orthogonal facet, not
a seventh lane. `Released` is label-less — the issue's closed state.

## Guardrails

- **Greenfield only (this skeleton).** Never apply to a migrant or current repo —
  the apply refuses (exit 3) rather than clobber. Backfilling missing pieces and
  reconciling a provisional banner belong to the migrant mode.
- **Never fork the suite.** This skill wraps `setup-matt-pocock-skills`; it never
  edits or re-implements Pocock's skills.
- **Bindings stay null here.** Do not hand-write role bindings into the stamp;
  the role-binding ticket owns live discovery.

## Out of scope (this skeleton)

- Migrant upgrade and current patch modes.
- Live role-binding discovery (#35).
- The optional Project board + CI-workflow projection (a prompted flex point).
- Standing up a multi-repo org — the wrapper configures a repo to *join* an org
  board; standing up the org is a one-time human act.
