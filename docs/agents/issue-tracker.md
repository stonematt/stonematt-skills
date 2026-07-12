# Issue tracker: GitHub

Issues for this repo live as GitHub Issues, grouped by GitHub Milestones, modeled on the [nitimini workflow](https://github.com/stonematt/nitimini/blob/master/docs/process/WORKFLOW.md). Use the `gh` CLI for all operations.

## Three-level hierarchy

| Level | Artifact | Lives in | Lifecycle |
|---|---|---|---|
| Roadmap | direction, themes | `README.md` (or `docs/product/ROADMAP.md` if it grows) | durable |
| Brief / PRD | scoped initiative | `docs/briefs/<name>.md` + GitHub Milestone | per-initiative |
| Issue | vertical slice | GitHub Issue | flows the status state machine |

The brief carries the **why** and architecture. Each child issue carries the **what** and acceptance criteria — issue bodies must stand alone so an agent can pick one up without reading back to the brief.

**PRDs are not issues.** When `/to-prd` produces a PRD, it writes the document to `docs/briefs/<name>.md`, creates a Milestone pointing at it, and stops. `/to-issues` then slices the brief into child issues under that Milestone.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies. New issues open at `status: triage`.
- **Read an issue**: `gh issue view <number> --comments`.
- **List issues**: `gh issue list --state open --json number,title,body,labels,milestone,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], milestone: .milestone.title, comments: [.comments[].body]}]'` with appropriate `--label`, `--milestone`, `--state` filters.
- **Comment**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Assign to milestone**: `gh issue edit <number> --milestone "<title>"`
- **Close**: `gh issue close <number> --reason "completed|not planned" -c "..."`
- **Create milestone**: `gh api repos/:owner/:repo/milestones -f title="..." -f description="See docs/briefs/<name>.md"`

`gh` auto-detects the repo from `git remote -v` when run inside a clone.

## When a skill says "publish to the issue tracker"

- If the skill is producing a **PRD/brief** (e.g. `/to-prd`): write `docs/briefs/<name>.md`, create a Milestone, and stop. Do NOT create a tracking issue for the PRD itself.
- If the skill is producing a **vertical slice issue** (e.g. `/to-issues`, `/triage`): create a GitHub Issue, assign it to the relevant Milestone, label `status: triage` (or whatever the skill's role maps to per [triage-labels.md](./triage-labels.md)).

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`. If a Milestone is referenced, also fetch the brief: `cat docs/briefs/<milestone-slug>.md` (or follow the milestone description's pointer).

## Branch and PR flow

- **feature → dev → main flow.** Feature branches (`feat/*`, `fix/*`, `docs/*`) branch off `dev` and PR into `dev`. `dev` is the integration branch; `main` is the release branch. `dev` PRs into `main` for releases. Never commit straight to `main`.
- **`main` stays the GitHub default.** It is the release + consumer branch: `skills.sh` (`npx skills add stonematt/stonematt-skills`) and Claude Code's `/plugin marketplace add` fetch the default branch, so consumers pull stable releases, not integration.
- **Pre-merge gate.** Run `./scripts/test.sh` before merging (feature→`dev` and `dev`→`main`). It validates skill structure/index consistency and the claude.ai zip smoke test.
- **Issue auto-close is release-gated.** `Closes #N` auto-close fires only on merge to the default branch (`main`), so feature→`dev` PRs do **not** auto-close their issues — issues close in a batch when `dev`→`main` releases. Close manually earlier if needed.
- Releases are git tags on `main`: `git tag -a vX.Y.Z -m "..."` then `git push --tags`. Tag when persona file shapes, generic skill bodies, or shim conventions change in a way that downstream consumers need to pin.

## Kanban board & status

GitHub Project [stonematt-skills](https://github.com/users/stonematt/projects/7) (#7) is the board view. **Issue `status:*` labels are canonical; the board's Status single-select is a CI-derived projection** — set labels, never the field by hand.

- **Status set (ordered):** `Triage → Ready → WIP → Blocked → Staged → Released`. Labels exist for all but `Released` (project-field only, set on close). `Blocked` is a side state; `Staged` = merged to `dev`, `Released` = closed via the `dev→main` release PR. See [triage-labels.md](./triage-labels.md).
- **`needs-info`** is an **orthogonal facet**, not a lane — it can co-occur with any status.
- **Eligibility:** `afk-ready` label (agent pickup) + native assignee (claimed).
- **Contextual slots:** `intent:{structural,voice,capability}` (selects the review lens); `area:*` is emergent (backward-aggregated, not pre-seeded).
- **CI sync** (`.github/workflows/`): `project-sync.yml` mirrors the `status:*` label onto the board; `clean-status-on-close.yml` strips `status:*` on close and sets `Released`. Both need the `PROJECT_TOKEN` secret (user PAT, `project` write — `GITHUB_TOKEN` can't write user Projects v2). **`issues`-triggered workflows run from the default branch (`main`) only** — board automation is live only once the workflows reach `main`; until then, sync issues to the board by hand.

## Wayfinding operations

Wayfinder maps/tickets use **GitHub-native** structure (no board dependency):

- **Map** = issue labelled `wayfinder:map` (canonical charting artifact). **Tickets** = child issues labelled `wayfinder:{research,grilling,prototype,task}` + executor facet `wayfinder:{afk,hitl}`.
- **Nesting (parent→child)** = native sub-issues via GraphQL `addSubIssue(input:{issueId, subIssueId})` with header `GraphQL-Features: sub_issues` (needs node IDs).
- **Blocking** = native REST `POST /repos/{owner}/{repo}/issues/{N}/dependencies/blocked_by -F issue_id=<blocker DATABASE id>` (the `.id`, not the issue number). Renders the frontier visually in the GH UI.
- **Frontier** = open + unassigned + no open blockers. **Claim** = assign to yourself (`gh issue edit N --add-assignee @me`).
- **The map sits on the kanban board; child tickets do not.** A map is long-running human effort, so it carries a normal `status:*` and appears on board #7: `triage` (filed) → `wip` (charting / resolving tickets — its usual state) → closed = `Released` (destination reached). Maps never enter `ready` or `staged` and carry no `afk-ready`. Child tickets keep their own axis (map + dependency edges + frontier query) and stay off the board.

## Release notes

When tagging, the tag annotation OR a paired GitHub Release should summarize:
- Skills added / removed / renamed
- Bucket moves that affect install selection
- Bundle (claude.ai) format changes that require a re-zip + re-upload

Downstream consumers consult tags + release notes to decide when to re-run `npx skills add ...` or rebuild their claude.ai bundle.
