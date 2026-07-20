# CI Workflow Templates — Spec

Make the two Projects-v2 CI sync workflows (`project-sync.yml`,
`clean-status-on-close.yml`) **deterministic templates** that `stone-adopt-pocock`
copies verbatim, instead of prose the model re-authors from scratch on every
adoption.

Extends the adopt-Pocock wrapper spec
([`adopt-pocock-wrapper.md`](./adopt-pocock-wrapper.md)); resolves the unsettled
`or` in its step 2d, which currently says the workflow files are *"the model's
judgment **or** the skill/CI layer."*

## Problem Statement

`stone-adopt-pocock` ships `scripts/pocock-board.sh` precisely so the model "never
freehands the hands-on GraphQL gotchas." That protection covers the **imperative**
GraphQL path (seeding the Status field, backfilling items) and stops there. The
**CI** GraphQL path — the same mutations, the same gotchas, running unattended on
every issue event — has no template at all. The model writes ~150 lines of YAML and
bash from memory on each adoption.

Three consequences, all now observed rather than hypothesized.

### 1. The fleet has already diverged

Three adopted repos carry **two materially different implementations**, each authored
freehand by a different run:

| | Variant A (~60 lines) | Variant B (~78 lines) |
|---|---|---|
| Status parse | `declare -A` map + `jq` | `case` over the raw JSON string |
| Label payload | `toJSON(…labels)` — full objects | `toJSON(…labels.*.name)` — names only |
| Closed-issue guard | `if: github.event.issue.state != 'closed'` | **absent** |
| `shell: bash` | explicit | implicit |

Variant A is better on every row. Nothing selected for it; the difference is which
run happened to write which file. There is no mechanism by which the better variant
propagates, and no way to tell from a repo which variant it got.

### 2. Regeneration reintroduces bugs

The most recent adoption shipped both workflows with a **YAML syntax error**: a step
name containing an unquoted `` `status: *` `` parses as a nested mapping (and `*` is
an alias indicator). Both files failed GitHub's workflow validation on push.

The failure mode is quiet and easy to miss:

- GitHub lists an invalid workflow by **file path** rather than its declared `name:`.
- It logs a run attributed to the **push** that introduced it, even though the
  workflow declares `on: issues`.
- That run has **no job log** — nothing to `gh run view --log-failed`.

A workflow that is *invalid* and one that is correctly *dormant* look identical
unless you parse the file. Variant A dodged this only because its step name happens
to contain no colon.

Worth noting the class: the canonical label vocabulary is `status: <lane>` — colon
**and** space — which is hostile to every colon-delimited or YAML-adjacent context it
touches. The same adoption run hit this three separate times (a test harness
delimiter, then both step names).

### 3. Hardcoded option ids are a latent landmine

Both variants bake the Projects-v2 `PROJECT_ID`, `STATUS_FIELD_ID`, and all six
single-select option ids into committed YAML.

But `pocock-board.sh status-field` **replaces** the Status field's option set —
its own header notes the returned ids are "CAPTURED and emitted as JSON for the CI
sync to consume." A replaced option set mints **new** option ids.

So any future re-adoption run that re-seeds the Status field silently invalidates
every hardcoded id in that repo's workflows. There is no error at seed time and no
error at workflow time — `updateProjectV2ItemFieldValue` against a stale option id
either fails into a log nobody reads, or worse, the workflow's fallback puts the
issue in the wrong lane. The failure surfaces as "the board is subtly wrong,"
weeks later.

This is the same class of blind spot as the repo↔project link bug: a data-layer
operation that succeeds while the human-visible outcome is wrong.

## Proposed Design

### Resolve ids at runtime, by name

The variable part of these files is three ids and a six-entry lane map. The invariant
part is ~150 lines. That ratio is backwards — we regenerate the large fixed part and
hand-copy the small variable one.

Invert it: have the workflow **discover** the board through the repo↔project link
that adoption now always establishes, and resolve the Status field and its options
**by name**:

```bash
gh api graphql -f query='
  query($owner:String!, $name:String!) {
    repository(owner:$owner, name:$name) {
      projectsV2(first:1) {
        nodes {
          id
          field(name:"Status") {
            ... on ProjectV2SingleSelectField { id options { id name } }
          }
        }
      }
    }
  }' -f owner="${GITHUB_REPOSITORY%%/*}" -f name="${GITHUB_REPOSITORY##*/}"
```

Consequences:

- The workflow file becomes **byte-identical in every repo**. No per-project
  substitution, so nothing needs generating — the determinism question dissolves.
- It **survives re-seeding**. New option ids are picked up on the next run.
- It ships as a literal file in the skill; adoption copies it. A re-run diffs to zero
  by construction, satisfying the idempotency bar.

Cost: one extra GraphQL call per workflow run. Irrelevant at issue-event frequency.

### Where the templates live

```
skills/in-progress/stone-adopt-pocock/
  references/workflows/
    project-sync.yml
    clean-status-on-close.yml
```

Adoption copies them verbatim into the target repo's `.github/workflows/`, the same
way `pocock-board.sh` is invoked by absolute path from inside the installed skill.
The dormancy contract is unchanged: inert until `PROJECT_TOKEN` exists **and** the
files reach the default branch.

### Adopt the better variant

Fold Variant A's wins into the template: `jq`-based status extraction, the
closed-issue job guard, explicit `shell: bash`. Quote every step name.

## Scope

1. Author both templates with runtime resolution (this repo).
2. Wire `setup-and-delta.md` step 2d to copy them; delete the "model's judgment" arm
   of the `or`.
3. Add a **parse gate** — validate the YAML before it is committed. A model that
   writes a workflow must not be the only thing asserting the workflow is valid.
4. Back-port to the adopted repos so the fleet converges on one implementation.

## Open Questions

- **Verify the id-invalidation claim.** The reasoning is sound and the helper's own
  comment supports it, but it was not tested — testing it means deliberately
  re-seeding a live board. Confirm on a throwaway project before relying on it as the
  motivating argument.
- **`projectsV2(first:1)` assumes one linked project.** A repo linked to several
  (one prior run found a stray personal project linked alongside the real board)
  needs a disambiguation rule — by title? by an explicit input? Fail loudly rather
  than guess.
- **Back-port ordering.** Convergence touches an org repo; worth confirming whether
  that lands as a normal PR or needs coordination.

## Out of Scope

- The imperative helper `pocock-board.sh` — unchanged, except for the `-F` → `-f`
  bug tracked separately.
- Label vocabulary, board lane names, the translation table.
- Any change to the dormancy contract.
