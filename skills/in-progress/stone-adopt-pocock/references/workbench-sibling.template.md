# Workbench sibling — template (placeholder content only)

Template the skill instantiates as `workbench/<date>-<slug>.md` — one file per adoption
run. `workbench/` is gitignored, so this committed copy is a template, never a live
sibling, and every value below is a **placeholder** (no real repo data). Full schema and
plumbing: [`workbench.md`](./workbench.md).

Copy the *structure*; fill the *values* from the actual run. The frontmatter must be
well-formed YAML (that is the schema's acceptance bar).

---

```markdown
---
suite_version: "1.4.0"          # installed Pocock suite version at this run
repo_kind: tracker-backed       # e.g. tracker-backed | trackerless-local
corrections_count: 3            # how many corrections the human made this run
unresolved:                     # open threads carried forward; [] if the run closed clean
  - "example: review role bind was ambiguous between two skills — deferred"
---

# <YYYY-MM-DD> — <slug>

## Proposed

<Placeholder> What the model proposed during the audit/bind — the binding recipe, the
substrate call, the label/board decisions. The shape of the proposal, before human
correction.

## Corrected + why

<Placeholder> What the human changed, and the reason. The "why" is load-bearing — it is
the correction signal a future run learns from. Example: "model bound
`review` to `commit-and-merge`; corrected to `ask-matt`-routed review because this repo
splits review from merge — the model assumed they were one role."

## Surprised

<Placeholder> What surprised the model — an assumption that broke, a repo shape it did
not expect, a bind that resolved differently than its prior implied. This is where a
genuinely new suite version leaves its fingerprint.
```

Notes:

- `unresolved: []` (empty) means the run closed clean. A **non-empty** `unresolved` is
  carried forward: the next read-before-audit pass pulls this sibling in regardless of
  `repo_kind`/recency so the open thread is never dropped (see `workbench.md`).
- `corrections_count` should match the number of distinct corrections captured in the
  "Corrected + why" slot — a cheap consistency check.
- This file is **local-only and never pushed**; record real detail at full fidelity on
  the operator's machine. The gitignore guarantees it cannot be committed — which is why
  no sanitization is needed. The committed template stays placeholder-only.
