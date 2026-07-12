# Workbench index — template (placeholder content only)

Template the skill instantiates as `workbench/INDEX.md` on the operator's machine on the
**first** adoption run. `workbench/` is gitignored — this committed copy is a template,
never the live index, and carries **placeholder rows only** (no real repo data).

One line per adoption run, newest-relevant first. One line means one line: date, slug,
and a one-line hook pointing at the sibling. Bodies live in the siblings, never here
(the index is an index, not a memory).

Line shape:

```
- <YYYY-MM-DD> — [<slug>](./<YYYY-MM-DD>-<slug>.md) — <repo_kind>, suite <suite_version>, <corrections_count> corrections[, UNRESOLVED] — <one-line hook>
```

Placeholder rows (replace with real runs; delete these on first real write):

- 2026-01-01 — [example-repo-a](./2026-01-01-example-repo-a.md) — tracker-backed, suite 1.4.0, 3 corrections — placeholder: model over-bound the review role
- 2026-01-01 — [example-repo-b](./2026-01-01-example-repo-b.md) — trackerless-local, suite 1.4.0, 1 correction, UNRESOLVED — placeholder: corpus subset, one open thread carried forward
