# v1.1 upgrade friction — Discord post to Matt Pocock's server

*Primary source, authored by Matt Stone, posted to Matt Pocock's Discord after the nitimini v1.1 upgrade. Captured as research input for map #31 (tickets #45 genesis, #36 migrant scope, #35 role-binding, #39 spec). Source: `/tmp/pocock-friction-preview.html`. Published gist: https://gist.github.com/stonematt/540133c3677452e71a072c23875684a4*

## The failure mode (THE breakage)

Finished a `/wayfinder` map, reached for the next stage, and **the environment fell over: the workflow doc, command map, and muscle memory all pointed at v1.0 names/shapes.** Concretely: *"my own project workflow didn't know `/to-spec` existed."* The skills upgraded cleanly; the **wrapping layer** did not. Nothing scanned the repo for references to renamed/removed skills, so the first sign was a step that used to work not working.

## Core lesson

**Upgrading a skills suite in a system that already wraps it is a migration of your wrapping layer, not a swap of the skills.** And the wrapping layer is standardized across ~a dozen repos — so v1.1 handed over **a dozen migrations, not one.** A manual reconcile is fine once; at fleet scale you need a **repeatable per-repo migration**, not a hand-edit each time. (This is the genesis of the adopt-Pocock wrapper project.)

## The wrapping-layer surfaces that go stale silently

- `WORKFLOW.md` — pipeline flowchart + command map
- `CLAUDE.md` / `AGENTS.md` process rules
- Forked commit/merge skills
- Custom `status:*` kanban conventions, issue-tracker conventions
- Prose that names or orchestrates Pocock's skills

## The fix that actually worked (not find-and-replace)

1. Research loop back through the `mattpocock/skills` GitHub repo to learn what really changed.
2. An `/ask-matt` pass to review and rewrite every wrapped asset against the new names **and contracts**.

## Two-half insight (directly answers #36 migrant scope)

**Audit-only misses the config half.** The working prompt runs `/setup-matt-pocock-skills` **first** (reconcile the suite's own config: issue tracker, triage labels, domain docs), **then** audits the wrapping layer. Both halves, in that order. → The migrant path is **not** "only rewrite `docs/agents/` config" nor "only rewrite prose" — it's **both: setup-reconcile the config seam, then full stale-ref + contract rewrite of the wrapper.**

## The product ask (= this project's core job)

Give `/setup-matt-pocock-skills` an **upgrade mode**: on re-run after a version bump, scan the repo for stale references to renamed/removed skills and flag them — same lever it already uses to inspect the repo and seed config. "Same skill, one new job." Note: user proposes *extending Matt's setup skill* rather than a separate fork — consistent with the map's **wrap-not-fork** founding decision; the wrapper leans on `/setup-matt-pocock-skills` first.

## Authoritative v1.0 → v1.1 delta (from the changelog; breaking PR: "v1.1: planning-skills unification (breaking)" — no alias/shim)

Renames (four, one is a merge):
- `to-prd` → `to-spec`
- `to-plan` + `to-issues` → `to-tickets` (**`to-issues` deleted**)
- `decision-mapping` → `wayfinder`
- `review` → `code-review`

Contract changes (the part that bit hardest — old *shape* runs under new name unnoticed):
- `/to-tickets` — tracer-bullet vertical slices, each declaring blocking edges; prefers **native sub-issues + native blocking** over body conventions; adds expand–contract strategy for wide refactors.
- `/tdd` — refactor stage dropped; **red→green only**, refactoring moved to `/code-review`; "seam" is the new leading word for where tests go.
- `/grilling` — added a **confirmation gate** + **facts-vs-decisions split** (facts looked up; decisions go to the human) so a grilling agent stops answering its own questions.
- `/wayfinder` — deliberately a **situational on-ramp, not the main spine** (making it the default is "a v2-sized move, not a 1.1").

## The manual migration prompt (user runs this per repo today — a prototype of the wrapper's behavior)

```
We just upgraded to v1.1 of Matt Pocock's engineering skills. Several skills were
renamed or merged and some contracts between them changed, but nothing in this
repo's own configuration was updated to match.

First, run /setup-matt-pocock-skills to reconcile the suite's own config
(issue tracker, triage labels, domain docs) with v1.1.

Then audit this repo's wrapping layer — workflow docs, CLAUDE.md / AGENTS.md rules,
custom or forked skills, issue-tracker and kanban conventions, command maps, and
prose — for anything still assuming the v1.0 skills, and migrate it. Account for:
  • to-prd → to-spec
  • to-plan + to-issues → to-tickets   (to-issues is deleted)
  • decision-mapping → wayfinder
  • review → code-review
  • contracts: to-tickets now uses tracer-bullet vertical slices with native
    blocking edges; tdd is red→green only (refactoring moved to code-review);
    grilling added a confirmation gate + facts/decisions split; wayfinder is a
    situational on-ramp, not the main spine.

Produce a migration plan first: list every stale reference and contract mismatch
you find, grouped by file, and let me review it. Then make the edits, and flag
anything ambiguous before changing it.
```
