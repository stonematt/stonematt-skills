# nitimini config — canonical spine for Adopt-Pocock

Extracted from `stonematt/nitimini` (the most mature instance of the workflow):
`docs/process/WORKFLOW.md`, `docs/agents/{issue-tracker,triage-labels}.md`,
`CLAUDE.md`, live GitHub labels, and Project v2 board #3
(`PVT_kwHOACsNbs4BWzgE`, Status field `PVTSSF_lAHOACsNbs4BWzgEzhSEz2M`).

Source of truth statement in nitimini: **"GitHub Issues + Project board #3 as the
single source of truth."** But mechanically the **issue labels are canonical** and the
board is a *projection* rebuilt from them by CI (see Board mechanism). That split is the
key finding for a portable spec.

---

## FIXED SPINE (the invariant that ports to every instance)

### 1. Board mechanism — labels drive, Project field reflects

Status is carried **redundantly** but with a clear authority direction:

- **Issue labels `status: *`** are the **driver / write surface**. Skills and humans set
  status by adding/removing the label.
- **Project v2 single-select `Status` field** is a **read/reflection surface**, set
  automatically from the label by CI. Nothing writes the field by hand in normal flow.
- Two GitHub Actions reconcile the two (both live on the **default branch `master`**, so
  the master version of the workflow is what runs):
  - `project-sync.yml` — on issue `opened / labeled / unlabeled`: adds the issue to the
    project and sets `Status` from the `status:*` label.
  - `clean-status-on-close.yml` — on issue `closed`: strips all `status:*` labels and sets
    project `Status = Released`.

Which axis carries what:

| Concern | Carried by | Mechanism |
|---|---|---|
| **Status** | `status: *` **label** (canonical) → Project `Status` field (reflection) | label is written; field is synced by CI |
| **Intent** | `intent:*` **label** | label only |
| **Area** | `area:*` **label** | label only |
| **Eligibility** | `afk-ready` **label** + **assignee** + (wayfinder) `wayfinder:afk`/`hitl` label | labels + native assignee |

The Project **board fields themselves are generic GitHub defaults** — Title, Assignees,
Status (the only custom single-select), Labels, Linked PRs, Milestone, Repository,
Reviewers, Parent issue, Sub-issues progress, Created/Updated/Closed. Only **Status** is a
custom single-select; everything else is off-the-shelf. So the board adds essentially
**one** piece of state (the Status single-select) beyond what labels already encode — and
even that is derived.

### 2. Status set + Kanban progression

Project `Status` single-select options (exact, in board order):
**Triage → Ready → WIP → Blocked → Staged → Released**

Issue-label vocabulary (exact label names):
`status: triage`, `status: ready`, `status: wip`, `status: blocked`, `status: staged`.
**`Released` has NO issue label** — it exists *only* as a Project Status option, set on
close by CI.

Progression (state machine from WORKFLOW.md):

```
[*] --> triage            (filed; ALL new work opens here, even known bugs)
triage --> ready          (AC written, scope tight, deps clear)
triage --> [*]            (declined / wontfix)
ready --> wip             (branch opened off dev)
wip <--> blocked          (side state: waiting on dep/decision; restore prior state on unblock)
wip --> staged            (PR merged to dev via /stone-merge)
staged --> Released       (release PR dev->master merged with "Closes #N")
Released --> [*]           (stays on the board forever; Insights time-window scopes views)
```

Notes that are part of the spine:
- **`blocked` is a side state**, not a column in the linear flow — it replaces the current
  state and is restored on unblock.
- **`staged` vs `Released`** are the dev/preview vs prod split: `staged` = merged to `dev`,
  `Released` = shipped to `master`/prod.
- `Released` is reached **only via auto-close keywords** (`Closes/Fixes/Resolves #N`) on a
  PR merging to the **default branch**. Feature PRs to `dev` may carry the keyword but it is
  inert until the release PR lands on `master`.

### 3. Eligibility flags — "who is allowed / expected to work this"

Expressed on **three orthogonal mechanisms**, not one:

1. **`afk-ready` label** — "brief tight enough for autonomous-agent pickup." **Orthogonal
   to `status:*`** (color `#0E8A16`). This is the general kanban eligibility flag.
   - There is **one** `ready` column. "Ready for agent" vs "ready for human" is NOT a second
     column — it's `status: ready` + `afk-ready` (agent) vs `status: ready` alone (human).
2. **Native GitHub assignee** — claim = `gh issue edit N --add-assignee @me`. An assigned
   issue is off the frontier (already claimed). This is the "currently owned by" signal.
3. **(Wayfinder subsystem only) `wayfinder:afk` / `wayfinder:hitl` label** — a *second,
   parallel* eligibility axis scoped to wayfinder tickets, making agent-vs-human glanceable
   on the board. Distinct from `afk-ready`. Defaults by ticket type: `research → afk`;
   `prototype`/`grilling → hitl`; `task → either`.

Canonical-role → nitimini mapping (the translation table Pocock skills use):

| Canonical role | nitimini label(s) |
|---|---|
| `needs-triage` | `status: triage` |
| `needs-info` | `status: blocked` (no true "waiting-on-reporter" state) |
| `ready-for-agent` | `status: ready` + `afk-ready` |
| `ready-for-human` | `status: ready` (alone) |
| `wontfix` | `wontfix` (native GH label) |

### 4. GH Project board — MANDATORY or flex point?

**The board is a FLEX POINT, not the spine.** Evidence:

- The **labels are self-sufficient**: `status:*` fully encodes the state machine; the board's
  only custom field (`Status`) is *derived* from those labels by CI. Delete the board and the
  workflow's state is intact on the issues themselves.
- The board's value is **reporting/visualization** (Insights burn-up grouped by Status,
  time-window scoping, milestone views) — not authority.
- Milestone attachment is explicitly optional: *"tickets may additionally be attached to a
  GitHub Milestone so they surface on the board / burn-up. The map issue remains the canonical
  coordinating artifact; the Milestone is just the flat board view."*
- Wayfinder maps use **native GitHub sub-issues + native issue dependencies** as the canonical
  UI-visible structure — again not the board.

So the portable spine = **labels + assignees + native sub-issue/dependency edges**. The
Project v2 board is a recommended-but-swappable read layer.

---

## CONTEXTUAL SLOTS (schema only — values are per-instance)

These namespaces are part of the spine; their **values** are project-specific and must NOT
be hard-coded into a portable spec.

### Intent — schema

- **Prefix:** `intent:<value>` (single-colon namespace, one label per issue expected).
- **Purpose:** declares the *nature of the change*, which drives the review contract.
- nitimini values (illustrative, NOT canonical): `intent:structural` ("refactor, no
  user-visible change; snapshot diff must be empty") and `intent:voice` ("copy/template/voice
  change; the snapshot diff IS the review"). The **pattern** to port is: *intent selects the
  acceptance/review lens*, not this specific pair.

### Area — schema

- **Prefix:** `area:<value>` (single-colon namespace; multiple may apply).
- **Purpose:** code-area / subsystem scope; also the trigger for **backward-aggregated
  milestones** (when the same `area:*` keeps reappearing in the bug/small-enhancement stream,
  a cleanup milestone is created retroactively).
- nitimini values (illustrative, NOT canonical): `area:auth`, `area:headlines`,
  `area:streams`, `area:voice-rules`. Port the **prefix + role**, not the strings.

### Other contextual label families seen (context, not spine)

- `kind:bse` — bug/small-enhancement, opportunistic throw-in work (an entry point into
  `triage`).
- `phase:1` / `phase:2` — milestone/phase grouping (project-specific).
- `priority: high` — escalation flag.
- `feedback` — athlete/beta feedback origin.
- `wayfinder:map` / `wayfinder:research` / `wayfinder:prototype` — wayfinder subsystem
  (its own spine, documented in `issue-tracker.md`).

---

## One-line takeaways for the spec

- **Canonical state lives on issue LABELS (`status:*`), not the board.** The Project v2
  Status single-select is CI-derived and optional.
- **Six statuses**, ordered `Triage → Ready → WIP → Blocked → Staged → Released`; `Blocked`
  is a side state, `Released` is label-less (project-field + close-hook only).
- **Eligibility = three orthogonal signals:** `afk-ready` label (agent-pickup), native
  assignee (claimed), and — wayfinder-only — `wayfinder:afk|hitl`.
- **Intent/Area are `namespace:value` label schemas**; port the prefix + role, leave the
  values to each instance.
- **The board is a flex point;** labels + assignees + native sub-issue/dependency edges are
  the portable spine.
