# Non-software & multi-repo flex catalog

Wayfinder ticket #33 (map #31). Survey of `~/src` repos **active in the last ~35 days**
(today 2026-07-11) that are **not primarily software**, plus the three named prototypes
(**astartum** = the `astrarum` GitHub org, **spokes**, **terrane**). Goal: catalog how the
Pocock / Matt-Stone workflow was already flexed for docs-heavy and multi-repo work, so the
wrapper can encode a **code-vs-docs** axis and a **single-vs-multi-repo** axis while the
fixed spine stays constant.

> Naming: the ticket's "astartum" is the `astrarum` org (tabletop / Greyhawk campaign
> system). It is the self-described outlier: many sibling repos, one shared board.

## The fixed spine (constant across every repo surveyed)

Every repo that has adopted the workflow carries the same skeleton, regardless of content
type or repo count:

1. **`docs/agents/{domain,issue-tracker,triage-labels}.md`** — the three-file agent brief.
2. **CLAUDE.md `## Agent skills`** block with `### Issue tracker`, `### Triage labels`,
   `### Domain docs` subsections that each point into `docs/agents/*`.
3. **GitHub Issues as the tracker**, driven entirely through `gh`; PRDs/briefs live in-repo
   (`docs/briefs/`, `BRIEF.md`, `ROADMAP.md`), not as issues.
4. **The nitimini triage core**: `triage`, `afk-ready`, `needs-info`, `ready`, `wontfix`
   (plus GitHub defaults). `afk-ready` is the orthogonal autonomous-agent flag everywhere.
5. **Wayfinder** operates the same way (map issue + child tickets + native dependencies)
   wherever it appears.

Everything below is what varies in the **contextual slots** around that spine.

## Surveyed repos (active < ~35 days)

| Repo | Owner | Type | Active | Workflow spine? | Board model | Notable flex |
|---|---|---|---|---|---|---|
| **obsidian-tyee** | stonematt | Docs/content (vault) | 2026-07-11 | Yes | none (uses milestones + wayfinder) | Vault is source of truth; GitHub is a *dispatch* layer only. No `status:*` kanban — **identity** label mapping. One-way cross-seam links. |
| **astrarum-greyhawk-campaign** | astrarum | Docs/content (play data) | 2026-07-09 | Yes | **org Project #1** (shared) | Scratch Instance; issues auto-add to org board; no per-repo milestones. |
| **orrery** | astrarum | Docs (governance) | 2026-06-22 | Yes | **org Project #1** (shared) | Governance repo; owns cross-repo ADRs + contracts; never tracks status locally. |
| **tabletop-gm-engine** | astrarum | Mixed (engine + rules) | 2026-06-22 | Yes | **org Project #1** (shared) | Engine repo, but rules/lore content dominant. |
| **world-borderland** | astrarum | Docs/content (world/lore) | 2026-06-22 | Yes | **org Project #1** (shared) | `vault/` + `library/`; content repo. |
| **forge** | astrarum | Docs (tooling notes) | 2026-06-22 | Yes | **org Project #1** (shared) | Minimal; docs-only. |
| **instance-template** | astrarum | Template (docs+submodules) | 2026-06-22 | Yes | **org Project #1** (shared) | Instance = play-assembly point (pins Engine+World). |
| **greyhawk-campaign** | astrarum | Docs/content (world/lore) | 2026-06-19 | Partial (CLAUDE.md, no docs/agents) | org board | Older-form campaign repo; spine not fully backfilled. |
| **camp-shrine-tracer** | astrarum | Docs/content (playtest) | 2026-06-23 | Partial (CLAUDE.md only) | — | Spike/playtest repo; lightweight. |
| **.github** | astrarum | Org config | 2026-06-12 | n/a | hosts `project-sync` template | Org-mechanical home: profile + org-default workflows. |
| **compass_team_insights_docs** | thebrightlink | Docs/content (analysis) | 2026-06-18 | Yes | (no owner board found) | Analytics/reporting docs repo with full spine. |
| **cda_launch** | lithos (local) | Docs/research | 2026-07-08 | Partial (CLAUDE.md) | local only (no remote) | `facts/ brief/ sources/ refs/`; research repo, no GitHub remote. |
| **lithos-site** | stonematt | Content (marketing site) | 2026-06-29 | (site) | stonematt Project #4 | Marketing content; own single-repo board. |
| **spokes** | thenorthwesthub | Software (dashboard) | 2026-07-11 | Yes | **thenorthwesthub Project #1** (own) | Named prototype: `status:*` kanban + `area:*` + `kind:bse`; wayfinder ops documented. |
| **terrane** | stonematt | Software (trading/backtest) | 2026-06-09 | Yes | (uses milestones for epics) | Named prototype: `status:*` kanban, `master`=prod branch flow, epic = brief+Milestone. |
| nitimini | stonematt | Software (the tracker itself) | 2026-07-11 | source | stonematt Project #3 | Origin of the triage vocabulary. |
| mcp-obsidian-cli / lookout / army_of_interns | stonematt | Software | recent | Yes | own | Baseline code repos (spine reference, not flex). |

## How the multi-repo → one-board case works (astrarum / "astartum")

The outlier is **not** a super-repo. Mechanism, verified from the repos + boards:

- **One org Project (v2) board**: `astrarum` org **Project #1 "Astrarum"** (`PVT_kwDOEXpuFs4BahU0`).
  It is the single cross-repo view. Large **epics live on the board**; **issues are delegated
  to member repos** and surfaced on it.
- **Auto-add via a shared workflow**: every member repo carries
  `.github/workflows/project-sync.yml` (distributed from the org
  `.github/workflow-templates/`). On `issues: [opened, reopened, transferred]` it runs
  `actions/add-to-project` against `https://github.com/orgs/astrarum/projects/1`.
- **Per-repo PAT, not org secret**: the workflow needs a `PROJECT_TOKEN` PAT set **per repo**
  — on GitHub Free, org-level secrets don't reach private repos, and `GITHUB_TOKEN` cannot
  write org-level Projects v2. This is the one real operational cost of the model.
- **Repo distinction on the board**: Projects v2's built-in **Repository** field auto-tags
  each item, so items from all repos coexist and can be grouped/filtered by repo. Cross-repo
  work-breakdown uses the built-in **Parent issue / Sub-issues** fields and board **Status**
  (single-select), *not* per-repo Milestones.
- **No per-repo Milestones**: ROADMAP phases map to **board Epics** on org Project #1. Each
  repo's `issue-tracker.md` states this explicitly ("no per-repo GitHub Milestones... ROADMAP
  phases map to board Epics on org Project #1").
- **Governance is centralized, status is not** (orrery ADR-0005, "governance not assembly"):
  the governing rule is *"coupling points toward the singular and stable, never toward the
  multiplying."* Cross-repo ADRs and the World↔Engine **contracts** live in `astrarum/orrery`;
  repo-local ADRs stay local and up-reference orrery ADRs (`orrery/ADR-0005`, `forge/ADR-0001`).
  A repo-local concern that turns out cross-repo **moves up** to the orrery, leaving a stub.
  Live status is deliberately kept **out** of the orrery — it lives only on the board.
- **Two system-level repos, split by job**: `astrarum/.github` = GitHub-mechanical org config
  (profile + `project-sync`, `clean-status-on-close`, PR template — the nitimini per-repo
  discipline hoisted to org scale); `astrarum/orrery` = semantic governance. Mechanics vs meaning.

Contrast: **spokes** and **terrane** are single-repo prototypes with their **own** board
(spokes → thenorthwesthub Project #1) or **Milestones** (terrane: epic = brief + Milestone +
child issues). They exercise the *workflow* flex (kanban, area labels, wayfinder) but not the
multi-repo/one-board flex.

## How docs-heavy repos flexed the contextual slots

The spine is identical; three slots change:

1. **Source-of-truth seam** (`domain.md` / `issue-tracker.md`). In code repos the repo *is*
   the source of truth. In docs repos it often is **not**:
   - **obsidian-tyee**: the **vault** is the source of truth; GitHub is a *dispatch/tracking*
     layer. Roadmap/strategy/ADRs/briefs all live in vault notes; a GitHub issue only *refers
     back* to a vault note by title. **Cross-seam links are one-way** (vault → issue URL;
     issue → vault by title only, no clickable link).
   - **orrery**: source of truth is the ADRs + `contracts/`; issues are downstream of a
     Seed→Grill→Crystallize→Track pipeline (grilling writes ADRs/specs *first*; only the
     crystallized outcome becomes issues). `to-issues` on a raw idea is forbidden.
   - **cda_launch**: `facts/ + sources/ + refs/` are the artifact; no GitHub remote at all.

2. **Triage-label slot** — the *core five stay fixed*, the *lifecycle overlay varies*:
   - **Product/software repos** (spokes, terrane) use the full `status:*` **kanban**
     (`triage → ready → wip → blocked → staged → released`) plus **`area:*`** labels
     (spokes: `area:etl/finance/impact/infra`) and `kind:bse`.
   - **Astrarum content repos** use a **flat** set — `triage / ready / needs-info /
     afk-ready / wontfix` — **no `status:*` kanban** (status lives on the org board, so
     duplicating it as labels would violate the coupling rule).
   - **obsidian-tyee** uses **identity mapping**: the five canonical triage roles map
     one-to-one onto same-named labels, **no kanban** ("internal package/runbook repo, not a
     product board").

3. **PRs-as-triage-surface slot**: docs/internal repos set **"PRs as a request surface: no"**
   (spokes, obsidian-tyee) — collaborator PRs are normal review, not triage intake. Only
   open-contribution repos flip this to `yes`.

4. **Branch/release slot**: varies independently of content — terrane uses `master`=prod +
   `dev` integration with `--no-ff`; others single-main. Not tied to the code/docs axis.

## FLEX REQUIREMENTS for the wrapper

### Constant (must NOT vary — the spine)
- The `docs/agents/{domain,issue-tracker,triage-labels}.md` trio + CLAUDE.md `## Agent skills`
  block pointing into them.
- GitHub Issues as tracker via `gh`; briefs/PRDs in-repo, not as issues.
- The five-role triage core (`triage/ready/needs-info/afk-ready/wontfix`) with `afk-ready`
  as the orthogonal autonomous flag.
- Wayfinder shape (map issue + child tickets + native dependencies).

### Code-vs-docs axis — what MUST vary
- **R1. Source-of-truth declaration.** `domain.md`/`issue-tracker.md` must state where truth
  lives: **in-repo** (code default) vs **external** (a vault / a `contracts/` + ADR set / a
  `facts/` corpus). When external, the tracker is a *dispatch layer* and cross-seam links are
  **one-way** (external → issue URL; issue → external by title only).
- **R2. Lifecycle overlay is optional.** Provide the `status:*` kanban as an **opt-in overlay**
  on the fixed five-role core. Docs/reference repos select **no kanban** (identity mapping) or
  **flat** (board-owned status); product repos select the full kanban. The wrapper must not
  hardcode kanban.
- **R3. Idea→issue gate.** Governance/docs repos need a **pre-issue pipeline** hook
  (Seed→Grill→Crystallize→Track): forbid `to-issues` on raw ideas; require the ADR/spec write
  first. Code repos can go idea→issue directly.
- **R4. PRs-as-request-surface = boolean slot**, defaulting to `no` for internal/reference
  repos, `yes` only for open-contribution.
- **R5. Area labels are content-defined**, not fixed — `area:*` (or none) is a per-repo slot.

### Single-vs-multi-repo axis — what MUST vary
- **R6. Board scope is a slot**: `own` (single-repo Project or Milestones) vs `shared org
  Project`. The wrapper must support pointing many repos at **one org Project (v2)**.
- **R7. Multi-repo board plumbing**: ship a `project-sync.yml` (auto-add on
  opened/reopened/transferred) via the org `.github/workflow-templates/`, and document the
  **per-repo `PROJECT_TOKEN` PAT** requirement (org secrets don't reach Free-tier private
  repos; `GITHUB_TOKEN` can't write org Projects v2).
- **R8. No per-repo Milestones in shared-board mode**: ROADMAP phases become **board Epics**;
  use built-in **Repository** field for repo distinction and **Parent/Sub-issue** fields for
  cross-repo breakdown. (In own-board mode, Milestones-as-epics is fine — terrane.)
- **R9. Governance split for multi-repo orgs**: a dedicated **governance repo** (orrery model)
  owns cross-repo ADRs + `contracts/`; a **mechanics repo** (`.github`) owns org workflows +
  profile. Coupling rule: *cross-repo decision → governance repo; local decision → local;
  status never written back to governance.* ADR numbering is per-repo-namespaced with
  up-references only.

### New fog / tickets surfaced
- **F1. Shared-board auth is fragile.** The per-repo `PROJECT_TOKEN` PAT is a manual,
  expiring, easily-forgotten secret — the weakest link in the multi-repo model. Wrapper should
  automate/verify it (or document a GitHub App path). Candidate ticket.
- **F2. Divergence risk — astrarum may be *too* divergent to templatize wholesale.** Its
  value is the **coupling rule + governance/mechanics split**, not a copyable file set. The
  wrapper should encode the *rule* (board scope + governance repo as slots), not try to
  generate an orrery. Flag on map #31.
- **F3. Spine backfill is incomplete** even within astrarum (`greyhawk-campaign`,
  `camp-shrine-tracer` have CLAUDE.md but not the full `docs/agents/` trio). A "spine audit /
  backfill" verb may be worth a ticket.
- **F4. Non-remote docs repos** (cda_launch, no GitHub remote) don't fit a GitHub-Issues
  tracker at all — a "trackerless / local-only" mode may be a fourth flex point beyond
  code-vs-docs.
