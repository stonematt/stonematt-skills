# Manual walkthrough — configuring stonematt-skills to the Pocock spine

Ticket #40. Real **audit/upgrade** case (not greenfield): `docs/agents/{issue-tracker,triage-labels,domain}.md`
already exist; labels partly present; **no** GH Project board, **no** CI sync, **no** wayfinder-ops section.

Dual purpose: (1) capture friction as highest-fidelity input to #35/#36/#38 and the spec (#39);
(2) leave this repo actually configured.

## Starting-state audit (vs nitimini canonical spine, #32)

| Spine element | nitimini | this repo (start) | gap |
|---|---|---|---|
| `status:*` labels | triage/ready/wip/blocked/staged | triage/needs-info/ready/wip/blocked | no `staged`; extra `needs-info` |
| `Released` | label-less, close-hook CI | absent | not instantiated |
| `afk-ready` | ✓ | ✓ | — |
| `wayfinder:afk\|hitl` | ✓ | ✗ | both missing |
| `intent:*` | structural, voice | `intent:structural` only | need value set |
| `area:*` | auth, headlines… | none | need values / defer |
| GH Project board | board #3 + Status field | none | flex point |
| CI sync | project-sync + clean-status-on-close | none | tied to board |
| tracker-doc wayfinding-ops | present | absent | friction |

## Friction log

<!-- one entry per decision point / gotcha / manual step, appended as the walkthrough proceeds -->

### D1 — Board: YES (full projection + CI), not label-only
- **Friction:** #32 rules the board a *flex point*; the natural default for a solo public docs/skills
  repo is label-only. But the human chose the board **in** for glanceable visibility.
- **Spec input (#39):** the board flex-point is a genuine per-repo **prompt**, not an auto-decision —
  and "not an app / no prod deploy" does **not** imply "skip the board." The wrapper must ask, not assume.
- **Cascade:** board wanted ⇒ instantiate GH Project + Status single-select + both CI Actions
  (`project-sync`, `clean-status-on-close`).
- **`staged`/`Released` semantics for this repo:** no prod deploy; `feature→dev→main`. So
  `status: staged` = merged to `dev`; `Released` = issue closed via `Closes #N` on the `dev→main`
  release PR (label-less, set by close-hook). Maps onto existing flow with no new deploy concept.

### D2 — Status swim-lane: anchor on nitimini's 6; `needs-info` is a facet, not a lane
- **Decision:** board Status single-select = exactly `Triage → Ready → WIP → Blocked → Staged → Released`.
  Keep the swim lane simple; do **not** add a 7th column.
- **`needs-info` reclassified:** it's a status-independent **filter facet** (can co-occur with triage /
  wip / blocked — "waiting on reporter" happens anywhere), so it leaves the `status:` namespace and
  becomes a bare orthogonal flag `needs-info`, sibling to `afk-ready`.
- **Spec input (#39):** better than nitimini, which loses the needs-info signal by folding it into
  `blocked`. The improvement stays lossless because it's **additive-orthogonal** — a new facet axis,
  never a mutation of the fixed 6-status spine. Confirms #4 (fixed spine vs orthogonal facets) and #6
  (divergence is free when lossless): a repo may enrich with orthogonal facets without forking the spine.
- **Mechanical:** add `status: staged`; rename `status: needs-info` → `needs-info` (drop `status:` prefix).

### D3 — Board instantiation: the Status field is NOT fully CLI-scriptable
- **Gotcha 1:** a fresh GH Project ships a built-in **Status** single-select (`Todo/In Progress/Done`).
  It is **un-deletable** — `deleteProjectV2Field` → `GraphQL: Only custom fields can be deleted.`
- **Gotcha 2:** `gh project field-create` can make a *new* single-select with options, but you can't have
  two fields named "Status", and the built-in can't be removed — so recreation is a dead end.
- **Working path:** overwrite the built-in field's options in place via raw GraphQL
  `updateProjectV2Field(input:{fieldId, singleSelectOptions:[…]})`. `gh` has **no CLI verb** for this;
  it must be a `gh api graphql` call. The mutation **replaces** the whole option set.
- **Spec input (#39):** board setup is **not** a pure `gh project` script. The wrapper must (a) create the
  project, (b) reach for `gh api graphql` to set the 6 Status options on the un-deletable built-in field,
  (c) capture the resulting field id + option ids for the CI sync. A naive "just use gh project field-create"
  recipe fails. This is the single fiddliest manual step in the whole board path.
- **IDs captured:** project #7 `PVT_kwHOACsNbs4BdKF0`; Status field `PVTSSF_lAHOACsNbs4BdKF0zhXtoiI`
  (options Triage/Ready/WIP/Blocked/Staged/Released).

### D4 — CI Actions ported (project-sync + clean-status-on-close)
- **Ported both** from nitimini verbatim except per-repo wiring: PROJECT_ID, STATUS_FIELD_ID, and the
  **six option ids** (per-board hex — captured above; nitimini's differ). Token choice = **(A) reuse the
  user-scoped `PROJECT_TOKEN` PAT** (project write scope covers all of stonematt's projects incl. #7).
- **Credential gotcha:** project mutations need a PAT with `project` write — `GITHUB_TOKEN` **cannot**
  write user-owned Projects v2. So there's an irreducible **human secret step**: `gh secret set
  PROJECT_TOKEN`. The agent can write the YAML but cannot provision the credential. Spec (#39): wrapper
  must emit a precise secret checklist and **stop**; hardened variant = fine-grained PAT (option B).
- **Activation-lag gotcha:** `issues`-triggered workflows always run from the **default branch** version.
  With `feature→dev→main`, these Actions are **dormant until the first `dev→main` release PR** lands them
  on `main`. Until then, board sync does nothing — expected, not a bug. Spec: warn that board automation
  goes live only after the workflows reach the default branch.
- **Contract note (#38, code-vs-docs):** these are *code* assets (executable CI). Under R-slot rules they
  demand higher-sensitivity handling than the docs/label changes — the walkthrough touched both classes,
  confirming the code-vs-docs seam is real within a single setup pass.

### D5 — Contextual slots: seed `intent:{structural,voice,capability}`, defer `area:`
- **intent** values chosen for a **skills/docs** repo: `structural` (refactor, no behavior change),
  `voice` (skill prose/persona/copy — snapshot diff IS the review), `capability` (new/changed skill
  behavior — acceptance = behavior test). Each selects a different review contract (confirms the #32
  "intent selects the acceptance lens" pattern ports without carrying nitimini's literal pair).
- **area** deferred: areas are **backward-aggregated** (born when a subsystem keeps reappearing);
  seeding upfront guesses wrong. Spec (#39): slot-resolution is **detect-then-confirm**, and `area:` in
  particular should default to *empty, emergent* — the wrapper must not fabricate an area taxonomy.

### D6 — Backfill: board = status-work only; wayfinder tickets stay off it
- **Decision:** the kanban board carries only `status:*`-labelled work; wayfinder issues (map + tickets)
  keep their own axis (map + native dependency edges, #7). Confirms two-axis coexistence isn't just
  conceptual — it forces a **backfill scope rule**.
- **Gotcha:** CI sync is dormant until it reaches `main`, so backfill is **manual GraphQL**
  (`addProjectV2ItemById` + `updateProjectV2ItemFieldValue`) per issue. Spec (#39, F3): the wrapper's
  backfill step can't lean on the freshly-added workflow — it must add existing issues by hand.
- **Orphan found:** #47 had a live `feat/47` branch but **no `status:*` label** → invisible to the board.
  Set `status: wip`. Spec input: audit case must **sweep for unlabelled open issues** and reconcile
  status from branch/PR state, not assume every issue already carries a lane.

### D7 — Tracker doc gap: no board or wayfinding-ops documentation
- **Friction:** `docs/agents/issue-tracker.md` documented issue conventions + branch flow but **nothing**
  about the kanban board mechanism, the `status:*` state machine, `needs-info`/`afk-ready` facets, intent
  slots, or **wayfinding operations** — the whole spine was implicit ("modeled on nitimini") and the
  GitHub-native wayfinder wiring lived only in agent memory.
- **Fixed:** added "Kanban board & status" + "Wayfinding operations" sections.
- **Spec input (#39):** configuring the tracker isn't done when labels+board+CI exist — the **agent doc
  must be written too**, or every future session re-derives the spine from nitimini. The wrapper must emit
  (or update) the tracker doc as a first-class output, not just mutate GitHub state.

---

## Spec-input rollup (for #39)

The manual pass confirmed and sharpened these, in priority order:

1. **Board is a per-repo prompt, not an auto-skip** — "docs/skills repo, no prod deploy" does *not* imply
   label-only (D1). Wrapper asks.
2. **Board setup is not pure `gh project`** — the built-in Status field is un-deletable; its 6 options must
   be set via raw `gh api graphql updateProjectV2Field`; capture field + option ids for CI (D3).
3. **Irreducible human secret step** — `PROJECT_TOKEN` PAT (`project` write); agent writes YAML, stops for
   the human to provision (D4).
4. **CI activation lags to default branch** — `issues` workflows run from `main`; board automation is
   dormant until then; backfill must be manual (D4, D6).
5. **Orthogonal facets enrich the fixed spine losslessly** — `needs-info` as a facet, not a 7th lane
   (D2); confirms #4/#6.
6. **Contextual slots: detect-then-confirm; `area:` stays emergent** (D5).
7. **Audit sweep for unlabelled issues** — reconcile status from branch/PR state (D6, #47).
8. **Tracker agent-doc is a first-class wrapper output**, not implicit (D7).
9. **Code-vs-docs seam is real within one pass** — CI YAML (code) vs labels/docs (D4, #38).
