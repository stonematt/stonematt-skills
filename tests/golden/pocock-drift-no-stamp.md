---
kind: pocock-drift
date: 2026-07-12
from_version: none
to_version: 1.4.0
freshness: migrant
---

# Pocock drift report — 2026-07-12

Suite drift from stamped `none` to installed `1.4.0`. Migration runs
config-first, then the wrapping-layer rewrite; this report hands off to
that flow. A "map that built successfully" is not proof of correct wiring.

## Migrant flow (ordered)

1. **Reconcile config first** — `docs/agents/{issue-tracker,triage-labels,domain}.md`
   to the installed suite. Audit-only misses this config seam.
2. **Then the wrapping-layer rewrite** — stale-ref **+ contract** rewrite of
   `CLAUDE.md` / `AGENTS.md` / prose. Find-and-replace misses the contract half.

## Drift

### Renamed / merged

- (none)

### Contract-changed

- to-spec: writes docs/briefs/<name>.md then stops (was an inline PRD issue)

### Added

- code-review
- diagnosing-bugs
- to-spec
- to-tickets
- wayfinder

### Removed

- (none)

### Bindings-shifted

- (none)

### Stale refs (wrapping layer)

- to-issues
- to-prd

