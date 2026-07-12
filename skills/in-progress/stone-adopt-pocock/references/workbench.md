# Workbench — the v2-durability engine (STORAGE ONLY)

The workbench is `stonematt-skills`'s durability engine across **unseen future suite
versions**: a local, growing ledger of what the model proposed during an adoption run,
what the human corrected and why, and what surprised the model. A future run reads it
before auditing a repo so the next proposal starts from accumulated correction, not
from scratch.

This reference scaffolds **storage only** — the layout, the gitignore invariant, the
frontmatter schema, and the read-before-audit / append-after **plumbing**. The
**feedback/update LOOP that *consumes* this ledger to improve proposals is OUT OF
SCOPE here and is tracked by [#60](https://github.com/stonematt/stonematt-skills/issues/60).**
This slice hands #60 a well-formed store with defined read/write points; it does not
build the improvement mechanism.

Spec: [`adopt-pocock-wrapper.md`](../../../../docs/briefs/adopt-pocock-wrapper.md) —
"The workbench (v2-durability engine)." The reconcile that reads-before / appends-after
is [`setup-and-delta.md`](./setup-and-delta.md) (its "Workbench" note); this doc defines
the store that note consumes.

---

## Layout — index + siblings (mirrors the auto-memory pattern)

The workbench mirrors the auto-memory **index + siblings** shape: one lean append-only
index, one sibling file per adoption run.

```
workbench/
  INDEX.md                 # one line per adoption run — the scannable ledger
  <date>-<slug>.md         # one sibling per run, full-fidelity body + frontmatter
  <date>-<slug>.md
  ...
```

- **`workbench/INDEX.md`** — one line per run, newest-relevant first. It is the fast
  scan surface: a read-before-audit pass reads *this* first, then pulls only the
  siblings it needs. Keep it to one line per entry (never paste body content into the
  index — that is the auto-memory `MEMORY.md` discipline: the index is an index, not a
  memory).
- **`workbench/<date>-<slug>.md` siblings** — one per run. `<date>` is ISO `YYYY-MM-DD`;
  `<slug>` is a short kebab identifier for the adopted repo/run (e.g.
  `2026-07-12-acme-api`). The full-fidelity body lives here, gated by the frontmatter
  schema below.

Templates for both files are committed alongside this doc (they are **not** under
`workbench/`, which is ignored — see the invariants):

- [`workbench-INDEX.template.md`](./workbench-INDEX.template.md)
- [`workbench-sibling.template.md`](./workbench-sibling.template.md)

The skill **instantiates** these on the user's machine at runtime (first run creates
`workbench/INDEX.md` from the index template; each run writes a sibling from the sibling
template). The committed copies are placeholders only — zero real repo data.

---

## Sibling frontmatter schema

Every sibling carries this YAML frontmatter. It is the machine-readable half; the prose
body (below) is the human-readable half.

| Field | Type | Meaning |
|---|---|---|
| `suite_version` | string | The installed Pocock suite version at the time of this run (e.g. `"1.4.0"`). The version axis: a future read filters/weights siblings by how close their suite is to the one now installed. |
| `repo_kind` | string | The substrate/shape of the adopted repo — e.g. `tracker-backed`, `trackerless-local`. The relevance axis: a read-before-audit pass prefers siblings whose `repo_kind` matches the repo about to be audited. |
| `corrections_count` | integer | How many corrections the human made during this run. A cheap signal of how much the model got wrong — high counts are the richest learning material for #60. |
| `unresolved` | list | Threads left open at the end of the run (ambiguous binds surfaced, questions unanswered, decisions deferred). Empty `[]` means the run closed clean. **Non-empty entries are carried forward** — a later run reads them as still-open (see read-before plumbing). |

Well-formed YAML is the acceptance bar for this schema (the templates validate). See
[`workbench-sibling.template.md`](./workbench-sibling.template.md) for the exact shape.

### Prose body slots

The body is three labelled slots — what the model proposed, what the human corrected and
why, what surprised the model:

- **Proposed** — what the model proposed during the audit/bind (the binding recipe, the
  substrate call, the label/board decisions — the shape of its proposal).
- **Corrected + why** — what the human changed, and the **reason**. The "why" is the
  load-bearing part: it is the correction signal #60's loop will eventually learn from.
  A correction with no reason is a weak entry.
- **Surprised** — what surprised the model: an assumption that broke, a repo shape it
  did not expect, a bind that resolved differently than its prior led it to believe.
  This is where a genuinely new suite version leaves its fingerprint.

---

## Invariants (non-negotiable)

- **Gitignored, local-only, never pushed.** `workbench/` is in the repo's `.gitignore`;
  nothing under it is ever tracked or committed. Each install grows **its own**
  workbench on the operator's machine — there is no shared/central copy and no sync.
- **Full-fidelity local — no sanitization burden.** Because the store is never pushed,
  siblings record real repo detail at full fidelity: real repo names, real binding
  decisions, real correction reasons. There is **no sanitization step** precisely
  *because* nothing here ever leaves the machine. (This repo is PUBLIC — the gitignore
  is what guarantees private-repo detail written into a workbench sibling can never be
  committed via this path. The committed templates carry placeholders only.)
- **Index is an index, not a memory.** `INDEX.md` stays one line per run; bodies live in
  siblings. Same discipline as the auto-memory `MEMORY.md`.
- **The consuming loop is [#60](https://github.com/stonematt/stonematt-skills/issues/60), not here.**
  This slice provides the store and the read/write points. Turning accumulated
  corrections into better proposals is #60's job.

---

## Read-before-audit plumbing

**Before** the model audits a repo (i.e. before the reconcile in `setup-and-delta.md`
proposes anything), it loads the workbench so its proposal starts warm:

1. **Read `workbench/INDEX.md`.** If the file does not exist yet (first run on this
   machine), the read yields empty — proceed with no prior. Absence is not an error.
2. **Select the relevant siblings** from the index. "Relevant" is, in priority order:
   - **Same `repo_kind`** as the repo about to be audited (a `tracker-backed` audit
     prefers `tracker-backed` siblings) — the strongest relevance signal.
   - **Recent** — newer runs over older ones, and runs whose `suite_version` is closest
     to the suite now installed (a sibling from a far-older suite is weaker prior).
   - **Unresolved carried forward** — any sibling with a non-empty `unresolved` list is
     pulled in **regardless of the two filters above**, so an open thread from a prior
     run is never silently dropped.
3. **Load those siblings' bodies** (proposed / corrected+why / surprised) as prior into
   the audit. That is the extent of the read: this slice *makes the prior available*.
   How the audit *weights* that prior into a better proposal is #60.

Plumbing only — this defines *which entries are loaded and when*, not how they change the
model's output.

---

## Append-after plumbing

**After** a run completes (the reconcile in `setup-and-delta.md` finishes), the model
appends the run to the workbench:

1. **Write a new sibling** `workbench/<date>-<slug>.md` from
   [`workbench-sibling.template.md`](./workbench-sibling.template.md): fill the
   frontmatter (`suite_version`, `repo_kind`, `corrections_count`, `unresolved`) and the
   three body slots (proposed / corrected+why / surprised) for *this* run.
2. **Append one line to `workbench/INDEX.md`** pointing at that sibling (date, slug, and
   a one-line hook — the same shape as the auto-memory index line). Create `INDEX.md`
   from [`workbench-INDEX.template.md`](./workbench-INDEX.template.md) if this is the
   machine's first run.
3. **Carry `unresolved` forward.** Whatever open threads the run leaves go in the
   sibling's `unresolved` list so the next read-before pass (step 2 above) surfaces them.

Plumbing only — the write happens; whether/how the accumulated corpus feeds back into
future proposals is [#60](https://github.com/stonematt/stonematt-skills/issues/60).
