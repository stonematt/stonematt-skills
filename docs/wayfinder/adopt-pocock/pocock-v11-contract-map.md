# Pocock v1.1 Suite — Contract Map

Ticket: #34 (wayfinder map #31). Feeds role-binding design in #35.

Source read: `~/.claude/.agents/skills/` **does not exist** — the actual install
lives at **`~/.claude/skills/`** (each skill a folder with `SKILL.md`, some with
bundled resource `.md`). A disabled duplicate `code-review` also sits in
`~/.claude/skills-disabled/`. Flag for #35: the ticket's stated path was wrong.

---

## Roster + I/O contracts

Every row read directly from `SKILL.md` frontmatter + body.
`dmi` = `disable-model-invocation` (true means slash-only, no autonomous model trigger).

| Skill | dmi | Purpose (one line) | Inputs (consumes) | Outputs (emits) | Chains to / from |
|---|---|---|---|---|---|
| **ask-matt** | true | Router over the suite — "which skill/flow fits my situation" | A situation described in prose | A recommended flow/skill | Names ALL of them; the map itself. Entry/dispatch, no artifact |
| **setup-matt-pocock-skills** | true | One-time repo config: issue tracker + triage labels + domain-doc layout | Repo state (`git remote`, CLAUDE/AGENTS.md, CONTEXT.md, docs/adr) | `docs/agents/{issue-tracker,triage-labels,domain}.md` + `## Agent skills` block | Precondition for to-spec, to-tickets, triage, code-review, wayfinder |
| **grill-with-docs** | true | Stateful relentless interview that leaves a paper trail | A plan/idea + a codebase | Sharpened idea; updates `CONTEXT.md` + ADRs | Drives `/grilling` + `/domain-modeling`; feeds `/to-spec` or `/implement` |
| **grill-me** | true | Same interview, stateless, no codebase | A plan/design (no repo) | Sharpened plan (nothing saved) | Drives `/grilling`. Standalone |
| **grilling** | — | The interview primitive: one question at a time, walk the decision tree | A plan/design + conversation | Shared understanding (no file) | Callee of grill-*, wayfinder, triage, improve-codebase-architecture |
| **domain-modeling** | — | Sharpen domain language; record ADRs (SoT for domain vocab) | Conversation, `CONTEXT.md`, ADRs, code | Updates `CONTEXT.md` glossary; writes `docs/adr/*.md` | Callee (grill-with-docs, wayfinder, triage, tdd, improve-codebase-architecture) |
| **codebase-design** | — | Deep-module vocabulary (module/interface/depth/seam/adapter) | A module/interface to shape (stateless ref) | Design vocabulary/decisions (no file) | Callee of `/tdd`, `/improve-codebase-architecture` |
| **research** | — | Delegate reading to a background agent vs primary sources | A question/topic | One cited Markdown file in repo | Feeds the main flow at `/grill-with-docs`. Standalone |
| **prototype** | — | Throwaway code to answer one design question | A design question | Throwaway prototype + captured answer (ADR/issue/NOTES) | Detour in main-flow step 2 (bridged by `/handoff`); wayfinder `prototype` tickets |
| **to-spec** | true | Turn the current conversation into a spec, publish to tracker | Conversation + codebase understanding | A spec (PRD) published as an issue, labelled `ready-for-agent` | From grill-with-docs / wayfinder → to `/to-tickets` or `/implement` |
| **to-tickets** | true | Split spec/plan/conversation into tracer-bullet tickets w/ blocking edges | A spec (path/#), plan, or conversation | Ordered `tickets.md` OR native issues w/ blocking links, `ready-for-agent` | From `/to-spec` → each ticket to `/implement` (clear context between) |
| **implement** | true | Build a piece of work from a spec/ticket | A spec or a ticket | Committed code on current branch | Drives `/tdd` at seams; closes with `/code-review` |
| **tdd** | — | Red-green-refactor; makes tests worth keeping | A behaviour + agreed seams | Failing→passing tests, one vertical slice at a time | Callee of `/implement`; speaks `/codebase-design` |
| **code-review** | **false** | Two-axis review (Standards + Spec) of a diff vs a fixed point | `git diff <point>...HEAD` + spec/issue + standards docs | Side-by-side Standards/Spec report (2 parallel sub-agents) | Callee of `/implement`; also standalone on any branch/PR |
| **triage** | true | Move incoming issues/PRs through a state machine of roles | Issues/external PRs you did NOT create | Labels + agent-ready briefs (or needs-info/wontfix) | On-ramp → `ready-for-agent` issues picked up by `/implement`; drives grilling+domain-modeling |
| **diagnosing-bugs** | — | Diagnosis loop for hard/intermittent bugs & perf regressions | A broken/slow symptom + codebase | A tight red→green loop, fix, regression test, post-mortem | On-ramp; post-mortem hands off to `/improve-codebase-architecture` |
| **wayfinder** | true | Chart a too-big-for-one-session effort as a shared map of investigation tickets | A loose, foggy idea + issue tracker | A `wayfinder:map` issue + child tickets producing **decisions not deliverables** | On-ramp; merges onto main flow at `/to-spec` (or `/implement`); ticket types call research/prototype/grilling |
| **improve-codebase-architecture** | true | Survey codebase for deepening opportunities (upkeep, not features) | A codebase, `CONTEXT.md`, ADRs | HTML report of candidates; inline CONTEXT/ADR updates | Picking one → main flow at `/grill-with-docs`; drives codebase-design, grilling, domain-modeling |
| **handoff** | true | Compact a conversation into a file to cross into a fresh session | Current conversation + optional next-focus arg | Handoff Markdown (OS temp) w/ suggested-skills section | The bridge between context windows (e.g. into/out of `/prototype`) |
| **teach** | true | Learn a concept over sessions using cwd as stateful workspace | A topic + workspace files | HTML lessons, learning-records, MISSION/NOTES | Standalone; names no sibling skills |
| *writing-great-skills* | — | Reference for authoring/editing skills well | — | Reference guidance | Standalone meta |

`code-review` is the **only** engineering skill left model-invocable (dmi absent/false) —
everything on the build path is slash-gated so the model won't wander into it mid-flow.
The three shared **callees** (`grilling`, `domain-modeling`, `codebase-design`) are also
model-invocable so parent skills can pull them in.

---

## v1.0 → v1.1 delta (observed evidence)

Confirmed against the ticket's hypothesised mapping — **all four hold**, plus new
skills that make the mapping *derivable* rather than a lookup table:

| v1.0 | v1.1 | Nature | Evidence |
|---|---|---|---|
| `to-prd` | **`to-spec`** | rename (PRD→spec) | to-spec desc: "produces a spec (you may know this document as a PRD)" |
| `to-plan` + `to-issues` | **`to-tickets`** | **merge** | to-tickets: "Break a plan, spec, or conversation into tickets… each declaring blocking edges" — subsumes both plan + issue-emission |
| `decision-mapping` | **`wayfinder`** | rename + reframe | wayfinder: shared map of investigation tickets producing "decisions, not deliverables" |
| `review` | **`code-review`** | rename + sharpen | now explicitly **two-axis** (Standards + Spec) in parallel sub-agents |

### Other renames / merges / NEW skills found beyond the table (flag for #35)

- **NEW `ask-matt`** — the router/index skill; did not exist in v1.0. It IS the flow model (see below).
- **NEW `setup-matt-pocock-skills`** — precondition/config skill; scaffolds `docs/agents/*` the others read. Makes the suite repo-configurable (tracker-agnostic: GitHub/GitLab/local/other).
- **NEW `handoff`** — explicit session-crossing bridge (`/handoff` forks; `/compact` continues). New primitive for the "smart zone" limit.
- **`grill` split into three** — `grilling` (primitive) + `grill-with-docs` (stateful, has codebase) + `grill-me` (stateless, no codebase). v1.0's single grill concept is now a primitive + two on-ramps.
- **NEW `codebase-design`** — deep-module vocabulary layer (module/interface/depth/seam), a shared callee alongside domain-modeling.
- **NEW `implement`** — explicit orchestrator that drives tdd internally and closes with code-review. The "build" verb is now its own skill, not implied.
- **`teach`, `writing-great-skills`** — off-flow standalones present in the install.
- **`triage`** — present as a real skill folder (with `AGENT-BRIEF.md`, `OUT-OF-SCOPE.md`), despite an earlier scan suggesting it was absent. It is a full state-machine on-ramp.
- **Tracker-agnostic contract** — v1.1 threads a `docs/agents/issue-tracker.md` config through to-spec, to-tickets, triage, code-review, wayfinder. The tracker is now a *seam*, configured once by setup.

---

## The ask-matt flow model (prose)

`ask-matt` is a **router**, not a doer (dmi: true). It encodes Pocock's mental model of
how the whole suite composes. The topology:

**One main flow (idea → ship), two on-ramps that merge onto it, plus standalones and
two vocabulary layers running underneath.**

**Main flow — `idea → ship`:**
1. **`/grill-with-docs`** — sharpen the idea by interview (stateful, leaves CONTEXT.md + ADRs). No codebase → `/grill-me` instead.
2. **Branch:** can every question be settled in conversation? If a question needs a *runnable* answer, detour through **`/prototype`** — bridged **out and back** by **`/handoff`** (open a fresh session against the file, prototype, hand the learning back).
3. **Branch:** multi-session build? **Yes** → **`/to-spec`** → **`/to-tickets`** (tracer-bullet tickets w/ blocking edges) → **`/implement`** per ticket, **clearing context between each**. **No** → **`/implement`** right here.
   - `/implement` always drives **`/tdd`** internally (one red-green slice) then closes with **`/code-review`** (Standards + Spec) before committing.

**Context hygiene:** steps 1–3 stay in **one unbroken context window** (don't compact/clear until after `/to-tickets`) so grilling, spec, and tickets share one line of thinking — bounded by the **smart zone** (~120k tokens). Each `/implement` then starts fresh from the ticket. `/handoff` is the escape valve when a session nears the smart-zone edge.

**On-ramps (situations that generate work, then merge onto the main flow):**
- **`/triage`** — incoming bugs/requests you didn't create → agent-ready issues → picked up by `/implement`. (Do NOT triage tickets `/to-tickets` already produced.)
- **`/diagnosing-bugs`** — something broken; builds a tight red loop first; post-mortem hands off to `/improve-codebase-architecture` when the finding is "no good seam."
- **`/wayfinder`** — a foggy effort too big for one session; charts a shared map of decision-tickets, then merges at **`/to-spec`** (or straight to `/implement` if it turned out small).

**Codebase health (upkeep, not features):** `/improve-codebase-architecture` surfaces deepening opportunities; picking one *generates an idea* that re-enters the main flow at `/grill-with-docs`.

**Vocabulary underneath (shared callees, single source of truth each):**
`/domain-modeling` (domain language, CONTEXT.md, ADRs) and `/codebase-design` (deep-module shape). Skills above pull them in; reach for them directly when the *words*, not the process, are the problem.

**Standalone / off-flow:** `/grill-me`, `/prototype`, `/research`, `/teach`, `/writing-great-skills`. **Precondition:** `/setup-matt-pocock-skills` before first engineering flow.

---

## Natural ROLES the suite implies (raw material for #35 role-binding)

The suite factors cleanly into a small set of roles. Each role = a phase-shaped
responsibility, realised by one or more skills:

| Role | Skill(s) that fill it | Contract (in → out) |
|---|---|---|
| **On-ramp / decision (fog → clarity)** | wayfinder, triage, diagnosing-bugs, improve-codebase-architecture | Raw situation (foggy idea / incoming issue / bug / cruft) → a decided, agent-ready starting point that merges onto the main flow |
| **Idea-sharpening (interview)** | grill-with-docs, grill-me (+ grilling primitive) | A loose plan → a shared understanding (with or without a paper trail) |
| **Spec** | to-spec | Conversation → published spec (PRD), `ready-for-agent` |
| **Slice-to-tickets** | to-tickets | Spec/plan → tracer-bullet tickets with blocking edges on the tracker |
| **Implement** | implement (drives tdd) | A ticket/spec → committed code, built test-first at agreed seams |
| **Review** | code-review | A diff + spec → two-axis (Standards + Spec) report |
| **Flow / ask (router)** | ask-matt | A situation → which skill/flow to use |
| **Session-crossing (bridge)** | handoff | A full conversation → a portable file for a fresh session |
| **Vocabulary layer (SoT)** | domain-modeling, codebase-design | Fuzzy terms / module shape → sharpened language + ADRs |
| **Investigation (feeds thinking)** | research, prototype | A question → a cited file / a throwaway answer |
| **Setup / precondition** | setup-matt-pocock-skills | Repo state → `docs/agents/*` config the suite reads |
| **Learning (off-flow)** | teach, writing-great-skills | A topic → lessons / authoring guidance |

**Key structural facts for #35:**
- The **tracker** (`docs/agents/issue-tracker.md`) is a configured seam every tracker-touching role reads — role-binding should bind to the *role*, not to GitHub specifically.
- `dmi: true` on all engineering-flow skills means roles are **slash-gated**; only the three vocabulary callees + `code-review` are model-invocable.
- Roles compose as a **DAG**, not a menu: on-ramp → sharpen → spec → tickets → implement → review, with vocabulary layers underneath and handoff as the cross-cut.
