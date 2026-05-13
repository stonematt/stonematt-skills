# Triage Labels

The engineering skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo, which follow the nitimini lifecycle vocabulary.

## Canonical role → repo label mapping

| Role in skills | Repo label(s) | Meaning |
|---|---|---|
| `needs-triage` | `status: triage` | New issue, needs scoping. All issues open here. |
| `needs-info` | `status: needs-info` | Waiting on the reporter for clarification. |
| `ready-for-agent` | `status: ready` + `afk-ready` flag | Spec'd, scope tight enough that an AFK agent (Sonnet, no human pings, very low uncertainty) can pick it up. |
| `ready-for-human` | `status: ready` (no `afk-ready`) | Spec'd but needs human implementation — too much uncertainty for AFK. |
| `wontfix` | close with `--reason "not planned"` | Declined. No label; the closed state is the signal. |

When a skill says "apply the AFK-ready label," apply BOTH `status: ready` AND `afk-ready`. The flag is orthogonal to status, per nitimini.

## Full lifecycle label set

Beyond the five triage roles, the issue state machine uses more labels. See [`issue-tracker.md`](./issue-tracker.md) and the nitimini workflow for the full state machine.

| Namespace | Label | Meaning |
|---|---|---|
| status (lifecycle) | `status: triage` | New, needs scoping |
| status | `status: needs-info` | Waiting on reporter |
| status | `status: ready` | Spec'd, awaiting pickup |
| status | `status: wip` | Branch open, work started |
| status | `status: blocked` | Waiting on dependency or decision |
| flag | `afk-ready` | Brief tight enough for autonomous-agent pickup. Orthogonal to `status:*`. |
| flag | `kind:bse` | Bug or small enhancement; opportunistic / throw-in work |
| flag | `priority: high` | Escalate scheduling |
| intent | `intent:structural` | Refactor with no user-visible change. Snapshot diff must be empty. |
| reference | `adr` | Issue references or proposes an ADR |
| area | `area:*` | Code area scope. Deferred — create on first use. |

Note: `status: staged` from the upstream nitimini set is omitted here. The single-main branch flow has no staging step — merged to `main` IS released-on-pull. If a future need for a staged step appears (e.g. a `next` branch for previews), reintroduce.

## Status transitions

```
(new) → status: triage
status: triage → status: ready (scoped, AC written, deps clear) — add afk-ready if tight enough
status: triage → (closed, not planned) — wontfix
status: ready → status: wip (branch opens off main)
status: wip ↔ status: blocked
status: wip → status: needs-info (if scope question surfaces mid-flight)
status: wip → (closed) — PR merged to main
```

## Setup status

The repo does not yet have these labels created. Initial scaffolding step will:

1. Create labels: `status: triage`, `status: needs-info`, `status: ready`, `status: wip`, `status: blocked`, `afk-ready`, `kind:bse`, `priority: high`, `intent:structural`, `adr`.
2. Defer all `area:*` labels until the first issue needs one.

This setup runs as a separate scaffolding step (probably first `/triage` invocation or a one-off `gh label create` script), not on every skill invocation.
