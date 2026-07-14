---
name: stone-adopt-pocock
description: One skill that adopts (installs OR upgrades — one idempotent path, no modes) Matt Stone's Matt-Pocock skill-suite setup on any repo. It runs Pocock's own `setup-matt-pocock-skills` for the suite spine, then overlays only the thin Stone delta — translation-table conventions, a durable version stamp with a live-discovered role-binding recipe, a stale-v1.0-prose rewrite, and an optional Projects v2 board. Manual, rare, context-quiet. Trigger only when a human explicitly runs it; the model never auto-fires it.
disableModelInvocation: true
---

# Adopt-Pocock wrapper

Adopt any repo to Matt Stone's standing Pocock-suite config in one run, leaving
nothing to finish by hand. **Wrap, never fork:** call Pocock's own
`setup-matt-pocock-skills` for the suite spine, then author only the thin Stone
delta on top. You (the model) lead; bash is only hands.

Spec: [`docs/briefs/adopt-pocock-wrapper.md`](../../../docs/briefs/adopt-pocock-wrapper.md).

## When this runs

- **Manual only.** `disableModelInvocation: true` — a human runs it deliberately.
- **Rare and context-quiet** — it must not bloat everyday sessions.
- **Install or upgrade is one path.** Detect nothing by directory age; one
  idempotent delta-reconcile backfills what is missing and clobbers nothing the
  human authored. Greenfield is just the case where the delta is everything.

## The run — six steps

### 1. Preflight (read-only gate)

Inspect the environment; halt on the first unmet precondition with the exact
copy-paste fix and stop — Matt fixes it in his own shell and re-invokes. Ask the
board opt-in question here too (label-only is the portable default).
Procedure: [`references/preflight.md`](./references/preflight.md).

**Preflight never mutates the machine or credentials** — no `gh auth refresh`, no
writes. You print fixes; Matt runs them.

### 2. Run `setup-matt-pocock-skills` (trust, never fork)

Invoke Pocock's own installer/reconciler for the suite spine. It is idempotent, so
this one call covers install and upgrade of *his* half. Trust its output — never
re-read, re-create, or patch what his setup owns (the `docs/agents/*` spine, the
label set, the installed skills). His half is verified transitively by the step-5
smoke, not by second-guessing it here.
Details: [`references/setup-and-delta.md`](./references/setup-and-delta.md) (step 1).

### 3. Present the directive (one go/no-go)

Audit the repo by **reading** it (not bash-probing), read the local workbench of
prior adoptions ([`references/workbench.md`](./references/workbench.md),
read-before-audit), then declare: the goal, per-repo success criteria, detected
contextual slots, and the planned Stone-delta mutations. This is the **single**
approval checkpoint. On go, run autonomously to done — re-surface only on a true
blocker (ambiguous bind, credential wall).

### 4. Overlay the Stone delta only

Author the seam between Pocock's way and Matt's — nothing his setup owns.
Procedure: [`references/setup-and-delta.md`](./references/setup-and-delta.md)
(step 2), with role binding in
[`references/role-binding.md`](./references/role-binding.md) and the stamp shape in
[`references/pocock-stamp.template.md`](./references/pocock-stamp.template.md). The
delta is: the translation-table conventions; the durable stamp carrying a
**live-discovered** binding recipe (read the installed suite — no slug table); the
targeted rewrite of stale v1.0 references in *Matt's* wrapping layer (never a
whole-file regen); and, if the board was opted in, the Projects v2 projection via
the bundled helper at `<this skill dir>/scripts/pocock-board.sh` (`labels` /
`status-field` / `backfill`) — never freehand GraphQL. The helper ships **inside
this skill dir**; invoke it by its absolute path within the installed skill, never
a cwd-relative `scripts/...` (cwd is the target repo, not this checkout). Plus a
**transient de-GSD nudge**: if the repo smells GSD-bootstrapped (a `phase-N` branch
law in the wrapping layer, `W<n>-<m>` issue titles), surface it, propose the canonical
topology-only form, and confirm — never rewrite history or auto-rename live issues; it
no-ops once the residue is gone. All of it runs as **one idempotent delta-reconcile**:
backfill missing, clobber nothing human-authored, a re-run produces zero diff.

### 5. Behavioral smoke (anti-silent-success)

Prove the wiring *runs*, not just that files exist — you (the model) drive it with
`gh` on the target repo. Create a throwaway issue, move it across the `status:*`
lanes, close it, confirming after each move that the board/labels reflect the
progression, then **clean it up** (delete or close so no litter). Guarantee the
cleanup even on error: guard the lifecycle so a mid-smoke failure still removes the
throwaway. This is model-led live judgment, not a script call.

> The offline CI counterpart is
> [`tests/pocock-acceptance-gate.sh`](../../../tests/pocock-acceptance-gate.sh)
> Part B (the self-verify seam) — a CI check, **not** a runtime dependency of this
> skill.

### 6. Verify, report, append the workbench

Check the declared success criteria by **reading the adopted repo**: spine present
(or corpus subset), the `## Agent skills` block, canonical labels (or `[]`), the
stamp written, no lingering v1.0 references in the wrapping layer, all
tracker-touching roles bound, `unresolved` empty. Report the outcome, then
**append this run** to the local workbench (sibling + one INDEX line) per
[`references/workbench.md`](./references/workbench.md) — the durability engine for
the next, unseen suite version.

> The automated CI counterpart is
> [`tests/pocock-acceptance-gate.sh`](../../../tests/pocock-acceptance-gate.sh)
> Part A — a CI check, **not** a runtime dependency of this skill.

## Guardrails

- **Wrap, never fork.** Call `setup-matt-pocock-skills`; never edit or re-implement
  Pocock's spine.
- **Never hand-write role bindings.** Discover them live from the installed suite.
  On an ambiguous (split) or vanished (empty) bind → **stop and surface**, never
  guess into durable config. **Flag** forked commit/merge skills — never
  auto-rewrite them.
- **Preflight never mutates.** Read-only readiness gate; halt with the fix, Matt
  runs it.

## Status

In-progress: this skill stays under `skills/in-progress/` until it runs clean on
3–4 real repos, then promotes out.
