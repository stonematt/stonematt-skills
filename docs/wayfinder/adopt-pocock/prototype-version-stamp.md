# Version-stamp + drift-report design (#37)

Decided shape (was a prototype; forks resolved in grilling). Unifies three
things into one artifact: the Matt-version **stamp** (#37), the #36 freshness
**fast-path** signal, and the #35 role-binding **recipe cache**.

Key call: **no content fingerprints.** Keyed on the version string alone — on any
bump the agent re-reads SKILL.md live (#35 discovery) and judges drift itself,
rather than storing hashes to detect an unbumped contract change (rare; Matt
bumps versions and writes good release notes). Under-engineer on purpose.

---

## A. The stamp — `docs/agents/pocock-stamp.md`

Sibling to `/setup-matt-pocock-skills`'s config (`issue-tracker.md`, etc.).
Markdown + YAML frontmatter: every sibling is `.md`, a human opens it and gets
it, frontmatter still machine-parses for the freshness check.

```markdown
---
suite: mattpocock/skills
version: "1.1"
stamped: 2026-07-11
source: ~/.agents/skills   # canonical catalog, NOT the ~/.claude/skills projection
# whole catalog, light: name + dmi + activated (symlinked into ~/.claude/skills)
catalog:
  ask-matt:                 { dmi: true,  activated: true }
  setup-matt-pocock-skills: { dmi: true,  activated: true }
  to-spec:                  { dmi: true,  activated: true }
  to-tickets:               { dmi: true,  activated: true }
  implement:                { dmi: true,  activated: true }
  code-review:              { dmi: false, activated: true }
  wayfinder:                { dmi: true,  activated: true }
  # … rest of installed catalog, name+dmi+activated only
# full bindings ONLY for tracker-touching roles (#35 narrow)
bindings:
  on-ramp:          [wayfinder, triage, diagnosing-bugs, improve-codebase-architecture]
  spec:             to-spec
  slice-to-tickets: to-tickets
  implement:        implement
  review:           code-review
  setup:            setup-matt-pocock-skills
---

# Pocock stamp

Recorded by the adopt-Pocock wrapper on 2026-07-11 against v1.1.
This file is the freshness fast-path (#36) and the role-binding recipe (#35).
```

---

## B. Staleness rule (the #35 seam this ticket owns)

On any run:
1. Read installed `version` from `~/.agents/skills`.
2. `installed.version == stamp.version` → **current**: trust the cached
   `bindings`, skip live re-discovery.
3. Else → **migrant**: re-discover bindings live (#35), emit the drift report,
   run the migrant flow (#36), then **overwrite the stamp** with the new recipe.

No fingerprints, so an unbumped contract change isn't auto-caught — acceptable;
the slug-scan (#36 belt-and-suspenders) and live re-read on the next real bump
cover it.

---

## C. Drift report — `docs/agents/pocock-drift-<date>.md` (+ echoed to session)

Written file (migration audit across ~a dozen repos = worth a record), also
printed to the session. Grouped by *kind of change*; drives the migrant flow.

```
Pocock drift report — stamp v1.0 (2026-05-02)  →  installed v1.1 (~/.agents/skills)

RENAMED / MERGED
  to-prd            → to-spec
  to-plan + to-issues → to-tickets      (to-issues REMOVED)
  decision-mapping  → wayfinder
  review            → code-review

CONTRACT CHANGED   (same name, new behaviour — the silent-breakage class)
  tdd        refactor stage dropped; red→green only
  grilling   added confirmation gate + facts/decisions split
  wayfinder  reframed as situational on-ramp, not main spine

ADDED     ask-matt · setup-matt-pocock-skills · handoff · codebase-design · implement
REMOVED   to-issues  (merged into to-tickets)

ROLE BINDINGS THAT SHIFTED
  slice-to-tickets   to-plan+to-issues → to-tickets
  review             review → code-review

STALE REFS IN WRAPPING LAYER   (slug-scan, #36 belt-and-suspenders)
  WORKFLOW.md   3× /to-prd, 1× /to-issues
  CLAUDE.md     1× /review
  → handed to migrant flow: config-reconcile, then contract rewrite
```

Note the CONTRACT CHANGED section is populated by the **live re-read** (agent
reads new SKILL.md + release notes), not by a stored hash diff.
