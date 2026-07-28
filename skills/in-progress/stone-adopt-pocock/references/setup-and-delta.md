# Setup invocation + Stone-delta overlay

The core of `stone-adopt-pocock`. Runs **after** [`preflight.md`](./preflight.md)
passes and the board opt-in is answered. You (the model) invoke Pocock's own setup
for the suite spine, then overlay **only** the Stone delta — the thin seam between
his way and Matt's. Install and upgrade are the same path; there are no separate
greenfield/migrant branches.

Spec: [`adopt-pocock-wrapper.md`](../../../../docs/briefs/adopt-pocock-wrapper.md) —
"Step one is invoking `setup-matt-pocock-skills`", "The Stone delta is the only thing
the wrapper authors", "Install-vs-upgrade dissolves into one idempotent
delta-reconcile".

Role binding (a sub-step of the delta) has its own procedure:
[`role-binding.md`](./role-binding.md). The stamp shape it produces:
[`pocock-stamp.template.md`](./pocock-stamp.template.md).

---

## Step 1 — Invoke Pocock's setup (trust, never fork)

Run Matt Pocock's own installer/reconciler. It owns the **suite spine** and is
idempotent, so this single call covers both a fresh install and an upgrade of *his*
half.

```bash
setup-matt-pocock-skills
```

**What his setup owns — never edit, never re-create:**

- the `docs/agents/*` spine his setup writes (the tracker + domain docs it authors);
- the canonical label set his setup creates;
- every skill under `~/.agents/skills` and its wiring.

**Trust-then-verify.** Do not re-read his output to "confirm" each file, and never
patch anything his setup produced — if it looks wrong, that is a Pocock-side bug, not
a thing the wrapper repairs. His half is verified transitively by the end-to-end
behavioral smoke (Seam 1 / #66), not by the wrapper second-guessing it here.

The one thing you carry forward from this step into the delta: **what the installed
suite currently exposes** (skill names, `SKILL.md` contracts, changelog, the
`ask-matt` router). Role binding reads those live — see `role-binding.md`.

---

## Step 2 — Overlay the Stone delta ONLY

The delta is the *only* thing the wrapper authors. Everything below is Matt's
convention layer on top of Pocock's spine — the seam, nothing more.

### 2a. Translation-table conventions (canonical role → board expression)

The wrapper's skills speak **canonical roles**; a repo expresses them however its
board is configured. The wrapper applies the mapping and **never learns board column
names**. Divergence between repos is free as long as the mapping stays lossless.

State these invariants **exactly** — they carry forward across suite bumps, do not
paraphrase them loosely:

| Canonical role (skills speak this) | Board expression |
|---|---|
| `needs-triage` | `status: triage` |
| `needs-info` | an orthogonal facet — **NOT** a lane/column |
| `ready-for-agent` | `status: ready` + the `afk` flag |
| `ready-for-human` | `status: ready` (no flag) |
| `Released` | label-less (the issue's closed state) |

Two invariants that are easy to get wrong:

- **The canonical flag is `afk`, NOT `afk-ready`.** `afk-ready` is a legacy alias
  some repos arrive carrying, not the canonical name. **Standing fleet rule: migrate
  it to `afk`** — rename the label in place (preserves issue associations + burn-up
  history) and rewrite the tokens; do **not** preserve it as a per-repo expression.
  (The host repo `nitimini`, which seeded this standard, migrated to bare `afk` for
  exactly this reason: `afk-ready` was judged misleading during the build.)
- **`needs-info` is a facet, not a seventh lane.** It rides orthogonally on top of
  whatever lane an issue is in; it never becomes a board column.

You do not hand-create these labels. The bundled board helper's `labels` verb
upserts the canonical `status:*` lifecycle labels plus the orthogonal `afk` and
`needs-info` facets idempotently. The helper ships **inside this skill dir** —
invoke it by its absolute path within the installed skill
(`<this skill dir>/scripts/pocock-board.sh`), never a cwd-relative `scripts/...`
(cwd is the target repo, not this checkout):

```bash
<this skill dir>/scripts/pocock-board.sh labels
```

`Released` is intentionally absent from that set — it is the closed state, not a
label.

### 2b. `docs/agents/pocock-stamp.md` — the durable version stamp

Write the wrapper's one owned durable artifact: a stamp recording the **suite
version** plus a **live-discovered binding recipe**. A future run reads it to tell
*current* from *drifted* at a glance.

- The binding recipe is **discovered live** by reading the installed suite — see
  [`role-binding.md`](./role-binding.md). **NO hardcoded slug table.** A slug table
  that breaks on a single rename is exactly what the pivot forbids.
- The stamp is wrapper-owned derived state, not human prose — regenerate it freely on
  every reconcile. It is the one file in the delta you fully own.
- Shape and frontmatter: [`pocock-stamp.template.md`](./pocock-stamp.template.md).

### 2c. Rewrite the stale v1.0 wrapping layer

Rewrite stale v1.0 skill references in **the layer Matt authored** so no old-shape
invocation runs silently under a new name. Scope is the wrapping layer only:

- `CLAUDE.md` / `WORKFLOW.md` (the `## Agent skills` block, workflow prose);
- command maps and convention docs that name skills or roles.

**Operationalize "clobber nothing":** this is a *targeted reference rewrite*, never a
whole-file regeneration.

1. For each wrapping-layer file, locate references to skills/roles by their **v1.0
   name or v1.0 contract shape**.
2. Replace only those references with the current binding (from the recipe in 2b) —
   the surrounding human narrative, ordering, and any hand edits stay byte-for-byte.
3. Anything **Pocock's setup owns** (2a's label set, the `docs/agents/*` spine his
   setup writes) is out of bounds here — you rewrite Matt's wrapper prose, not
   Pocock's spine.
4. A reference that is *already* current is left untouched (this is what makes a
   re-run a no-op).

If a "stale" reference points at a **forked commit/merge skill** Matt customized,
do **not** rewrite it — flag it (see `role-binding.md`, forked-skill rule).

### 2e. Transient de-GSD nudge (fires only on GSD residue, else no-op)

Some repos were GSD-bootstrapped and carry residue that clashes with the canonical
topology. This is a **transient hint, not durable machinery** — no classifier table, no
stamp field, no regex battery. If the repo smells GSD, surface it, propose the canonical
form, and confirm with the human. Once adoption has run everywhere the residue is gone and
this no-ops forever. Trust future model reasoning for the judgment.

**Two smells to hint (issue #84):**

1. **Branch-convention law** — a `phase-N-<slug>` (phase/workstream) branch *law* in
   `CLAUDE.md` / `WORKFLOW.md`. This is wrapping-layer prose → **rewrite** toward the
   canonical (extends 2c): from the `nitimini` reference, **no branch-name template** —
   topology only (feature branch off `dev` → `main`/`master`, short descriptive slug).
2. **Ticket names** — live issue titles carrying GSD workstream IDs like `W<n>-<m> · …`.
   Canonical: ticket id = `#N`; blocking = native sub-issue / dependency edges. **Do NOT
   auto-rename live issues** — surface the list for a human ok.

**Guardrails (remind, don't table):**

- Phase *language* spans **live convention** (rewrite) and **real history** (leave — "Phase
  3 generated these assets" is a true record). Never rewrite history.
- Dead GSD docs (`execution-plan.md`) → mark **superseded**, don't delete.
- Forked commit/merge skills already absorb the concrete breakage GSD caused (PRs merging
  with no `Closes #N` because the branch carried a phase number, not an issue — fixed in
  `stone-commit`'s multi-`Closes` and `stone-merge`'s staged flip). **Flag** those forked
  skills, never rewrite them (see `role-binding.md`, forked-skill rule).

### 2d. Board projection + dormant CI (board opt-in / written regardless)

- **If the board was opted in** (see preflight's board question): project the label
  spine onto a GitHub Projects v2 board using the bundled helper — never freehand the
  GraphQL. Overwrite the un-deletable built-in Status field in place and capture its
  field + option ids, then backfill existing issues:

  Invoke the bundled helper by its absolute path within the installed skill
  (`<this skill dir>/scripts/pocock-board.sh`), never a cwd-relative `scripts/...`:

  ```bash
  <this skill dir>/scripts/pocock-board.sh status-field --field-id <STATUS_FIELD_ID>
  <this skill dir>/scripts/pocock-board.sh backfill --project-id <PROJECT_ID> --field-id <STATUS_FIELD_ID>  # pairs on stdin
  ```

- **The CI sync workflows are written regardless** of the board answer. They stay
  **dormant** until *both* the `PROJECT_TOKEN` secret exists **and** they reach the
  default branch via `dev → main`. Writing them is never a blocker; "auto-sync later"
  is a note, not a straggler. On a **label-only** or **trackerless-local** adoption
  the live board projection (`status-field` / `backfill`) is skipped, but the dormant
  workflow files are still written.
- **Do NOT prompt for `PROJECT_TOKEN` here.** Its need is surfaced up front by the
  board-only preflight advisory (preflight check 5), so by the time you write the
  workflow the operator has already seen the `gh secret set PROJECT_TOKEN` fix.
  Write the dormant workflow and, if the secret is still absent, leave a one-line
  note that auto-sync stays dormant until it is set — never a mid-run credential
  prompt.

---

## Step 3 — One idempotent delta-reconcile (install == upgrade)

There is **one** path. Install (greenfield) is just the special case where the delta
is "everything"; upgrade backfills whatever is missing. There are **no** separate
migrant/greenfield code paths — do not branch on repo age.

**Reconcile the delta:**

- **Backfill what is missing** — any delta artifact (2a labels, 2b stamp, 2c current
  references, 2d workflows) that is absent, write it.
- **The de-GSD nudge (2e) is transient, not backfilled.** It fires only when GSD residue
  is present and no-ops otherwise — it is not a durable artifact a re-run re-asserts.
- **Clobber NOTHING the human authored.** Operationalized per artifact:
  - *Pocock's spine* (2a labels, his `docs/agents/*`): never touched — his setup owns
    it.
  - *The stamp* (2b): wrapper-owned derived state — regenerate freely.
  - *Wrapping-layer prose* (2c): targeted reference rewrite only; human narrative and
    hand edits are preserved (see 2c operationalization).
  - *Labels* (2a): the bundled `<this skill dir>/scripts/pocock-board.sh labels`
    upserts canonical config — it
    edits label definitions only, never touches issues.
- **Re-running changes nothing.** When the stamp's `suite_version` already matches the
  installed suite, every binding resolves, no stale v1.0 reference remains, and the
  canonical labels exist, the reconcile is a genuine no-op. Idempotency is the
  acceptance bar (issue #64): a second invocation on an already-adopted repo produces
  zero diff.

**Stop-and-surface still applies mid-reconcile.** If role binding hits an ambiguous or
vanished bind, or a forked commit/merge skill, the reconcile halts and surfaces per
`role-binding.md` — it never guesses a bind into durable config, even to "finish" the
reconcile.

**Workbench.** Read the local workbench before auditing the repo and append what was
proposed / corrected / surprised after — the durability engine for the next, unseen
suite version. The workbench *storage* (gitignored, local-only) is scaffolded by
slice #65; this reconcile is its read-before / append-after consumer.

---

## Verify

Do not assert on internal reasoning. The delta is proven by outcome through Seam 1
(#66): the spine present (or the corpus subset), the `## Agent skills` block, the
canonical labels created (or `[]` for a corpus), the stamp written, no lingering v1.0
references in the wrapping layer, all tracker-touching roles bound — plus the
behavioral smoke that drives a throwaway issue across lanes and cleans it up.
