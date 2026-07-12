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
- The optional Project board + CI-workflow projection (a prompted flex point).
- Standing up a multi-repo org — the wrapper configures a repo to *join* an org
  board; standing up the org is a one-time human act.
