# `pocock-stamp.md` — template / shape reference

The durable version stamp the Stone delta writes to `docs/agents/pocock-stamp.md` in
the adopted repo (see [`setup-and-delta.md`](./setup-and-delta.md) step 2b). It records
the **suite version** and a **live-discovered binding recipe** so a future run can tell
*current* from *drifted* at a glance.

**This is a shape reference, not a fill-in-the-blanks form.** The `bindings:` values
below are illustrative — they are **discovered live** per `role-binding.md`, never
copied from a table here. A stamp that hardcodes a slug table is exactly what the pivot
forbids.

Copy the *structure*; discover the *values*.

---

## Frontmatter fields

| Field | Meaning |
|---|---|
| `suite_version` | The installed Pocock suite version at adoption time. The drift signal: a later run compares this against the suite it finds installed. |
| `stamped` | ISO date the stamp was (re)generated. |
| `substrate` | `tracker-backed` or `trackerless-local`. A trackerless-local corpus carries `labels: []` and no board. |
| `board` | `none` (label-only, the portable default), `own`, or `shared` (member of an existing org board). |
| `labels` | The canonical labels applied, or `[]` for a trackerless-local corpus. |
| `bindings` | The **live-discovered** role → installed-skill recipe. One entry per bound tracker-touching role; `via` records which authority source resolved it. |
| `forked` | Commit/merge skills Matt has forked — **flagged, never rewritten** (`role-binding.md`). Empty when none. |
| `unresolved` | Ambiguous/vanished binds surfaced but not written. **Must be empty on a fully-adopted repo** — a non-empty `unresolved` means the run stopped-and-surfaced and is not done. |

`bindings` and `unresolved` are the drift/completeness contract; `suite_version` is the
version contract. Together they let a future run answer "is this repo current, drifted,
or half-adopted?" without re-deriving anything.

---

## Example stamp (values illustrative — discover, don't copy)

```markdown
---
suite_version: "1.4.0"        # whatever setup-matt-pocock-skills installed
stamped: 2026-07-12
substrate: tracker-backed
board: own
labels:
  - "status: triage"
  - "status: ready"
  - "status: wip"
  - "status: staged"
  - "status: blocked"
  - "afk"
  - "needs-info"
# --- live-discovered binding recipe (NO hardcoded slug table) ---
bindings:
  on-ramp:          { skill: <discovered>, via: skill-md }
  spec:             { skill: <discovered>, via: changelog }
  slice-to-tickets: { skill: <discovered>, via: skill-md }
  implement:        { skill: <discovered>, via: skill-md }
  review:           { skill: <discovered>, via: ask-matt }
  setup:            { skill: setup-matt-pocock-skills, via: skill-md }
  wayfinder:        { skill: <discovered>, via: skill-md }
forked: []          # e.g. [{ role: commit, skill: <matt-fork>, note: "human-owned" }]
unresolved: []      # non-empty => run stopped-and-surfaced; NOT fully adopted
---

# Pocock suite stamp

This repo is adopted to Matt Pocock's skill suite **v1.4.0** via
`stone-adopt-pocock`. The `bindings` above were discovered live from the installed
suite (authority order: release notes → `SKILL.md` contract → `ask-matt`), not read
from a slug table.

A future adopt run reads this stamp: if `suite_version` matches the installed suite,
every `bindings` entry still resolves, `unresolved` is empty, and no stale reference
remains in the wrapping layer, the repo is **current** and the reconcile is a no-op.
Otherwise it is **drifted** — rebind live and regenerate this stamp.
```

Notes on the example:

- The `bindings` values shown as `<discovered>` are placeholders — a real stamp carries
  the actual installed skill name each role resolved to. `setup` is shown resolved
  because it is definitionally Pocock's own `setup-matt-pocock-skills`.
- `via` is one of `changelog`, `skill-md`, `ask-matt` — the authority source that
  resolved the bind (see `role-binding.md` authority order).
- On a **trackerless-local corpus**: `substrate: trackerless-local`, `board: none`,
  `labels: []`, and the body notes the corpus subset (domain doc + stamp, no tracker
  machinery). The binding recipe still applies when a suite is installed.
- The `labels` list mirrors what the board helper's `labels` verb upserts;
  `Released` is intentionally absent (it is the closed state, label-less).
