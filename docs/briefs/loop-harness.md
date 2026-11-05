# Loop Harness — Brief

Take one release milestone to done in a short window, with the owner steering
and not in the loop. One AI ecosystem builds. The other runs QA and merges. A
planner writes the plan once, a cheap stateless runner walks it, and the owner
is asked only at named gates.

This brief replaces `/swarm` (`skills/in-progress/swarm/`) for release work. It
also absorbs the thin-orchestrator brief (#113). The claim lock, the report
contract, the delegated reads and "pointers, not content" now live here.

**Status:** draft. Nothing here is built yet.

**Not in scope:** judgment work. Grilling, interviews, design rounds, wayfinder
and to-spec keep their `/clear` + `/handoff` cadence. For them, that cadence is
part of the method. One small change for them rides along: the handoff reader
hook (Scope, item 7).

## Origin

Two sources of evidence point at the same design.

### Session transcripts

Transcript analysis of roughly 20 sessions over four days in one private app
repo turned up 12 handoffs. Peak context per session ran from 100k to 424k, and
nothing ever compacted. The handoffs came at phase boundaries, not at a hard
ceiling.

Delegation already worked. The orchestrator never watched CI or read a full
diff itself. One session turned a single instruction into 17 subagents and 8
merged PRs. Another took an issue from triage to merge on three typed human
turns. One session drove four issues end to end over about 14 hours and peaked
at 424k: roughly 100k of orchestrator context per issue, even though subagents
did every build, review and CI watch. (That is the session total divided by
issues, not a per-issue measurement.)

**The harness was already doing the work. The human was doing the context
resets.** Five problems showed up.

1. **Orienting reads landed in the main context.** What filled the
   orchestrator was its own orientation, not the work:

   | Consumer | Size per occurrence | Pattern |
   |---|---|---|
   | `gh issue view` on a batch of issues | 13–14k chars | read once per session |
   | Runbook / status docs | 5–13k chars each | re-read in 4+ consecutive sessions |
   | The previous session's handoff doc, via `cat` | 7–11k chars | every session that continued from a handoff |
   | `SKILL.md` bodies via `cat` | 6.5–10k chars | instead of the `Skill` tool or a subagent |
   | `stone-merge` `SKILL.md` | 378 lines | loaded again on every merge |
   | Swarm profile pasted into each lane brief | ~210 lines | emitted once per lane |

   None of it needs the orchestrator's reasoning. It stays inline because each
   item is one cheap-looking Bash call made to orient before a dispatch.
2. **The reset was manual.** `/handoff` writes free-form markdown to the OS
   temp directory, with no fixed path, no index and no reader. The human
   pastes the path, and the next session reads the whole document back in.
   Every reset costs a human turn plus 7–11k tokens of restated state. Most of
   that state already lives in the tracker as labels, PRs and merge SHAs.
3. **`/swarm` had the right shape, but it leaked and went unused.** A swarm
   lane is a fresh context per ticket. But the orchestrator did the queue,
   fence, profile, verify and salvage reads itself. Swarm also had no
   single-issue entry, and the common case is one or two issues arriving from
   triage. It was invoked zero times across every repo in the window.
4. **Nothing claimed an issue.** Two windows ran the same
   triage → implement → merge sequence on the same issue at the same time,
   for about 50 minutes. That is duplicate spend plus a merge race.
5. **Drift made lanes stop and ask.** A committed swarm profile said
   `CONTEXT.md` and `docs/adr/` did not exist; both did. The repo's lifecycle
   doc and `stone-commit` / `stone-merge` disagreed on landing rules. Each
   contradiction is a place where a lane stops for a human or guesses.

### A cross-ecosystem loop

A second app repo ran a Codex loop driver next to the owner's interactive
Claude session. The driver ran `codex exec` once per pass against one goal
issue. Each pass took the first unchecked, ungated task in the goal checklist.
It cut a branch, opened a PR, reviewed it on two axes (Standards and Spec),
merged it, and ended with a `STATUS:` line: `continue`, `gate`, `done`,
`blocked`, or `handback <pr>`.

`handback` existed because the Codex sandbox could not run the local server.
Codex left the PR open. The driver polled for the merge for up to 2 hours. The
owner's Claude session ran the QA pass with its browser tools, merged, and
recorded the task. Anything still uncertain became an owner gate with a
`Look:` list.

What worked:

- **A serial goal checklist.** One builder, one task at a time, so there were
  no collisions and no need for fencing.
- **Cross-model QA.** A different model reviewed the work than the one that
  wrote it.
- **The gate form.** A `Look:` list tells the owner where to go and what would
  look wrong, not a yes/no checklist.

What did not:

- **Nothing claimed an issue** here either. Overlap with the owner's other AFK
  work was avoided only by exclusion lists ("that issue is Codex's").
- **Every comment posted as the owner.** GitHub could not tell which agent did
  what.
- **The QA side was a person's session, not a loop.** If the owner was away,
  the 2-hour wait ran out and the driver exited. The goal stalled.
- **Merge authority differed by agent.** Codex merged its own PRs. Swarm lanes
  may not merge. The rules were written in three documents that disagreed —
  the same drift as problem 5.
- **A shared worktree.** The driver ran `git reset --hard` in a worktree the QA
  session also worked in. Unpushed QA edits would be lost.

## Goal

- Ship a milestone in a short window without side quests.
- Keep the owner steering: they set scope and answer gates, nothing else.
- No `/handoff` anywhere in mechanical work.
- Protect Claude budget. Move build tokens to an otherwise idle Codex
  subscription.

## Principle: pointers, not content

The tracker is the state. No role carries state between runs. Each run reads
what it needs from GitHub, acts, and hands on or exits.

For the runner this is literal: it is stateless, so it never needs a handoff.
Across all its runs, its context for one ticket should be four things:

1. The builder dispatch.
2. The builder's report.
3. QA's verdict. A report is a claim, and "pointers, not content" must never
   collapse verification into trusting it. Here the independent check is QA,
   running in the other ecosystem.
4. The merge result, plus the one-line cleanup acknowledgement.

**Target: at most about 5k runner tokens per ticket.**

Working rule for the runner and the planner: **never run a command whose
output you did not ask to have summarized.** Where a role needs a fact, a
subagent fetches the fact. QA reads what it reviews; its other reads are
delegated too.

## Roles

| Role | Default | Runs as | Does | Never |
|---|---|---|---|---|
| **Planner** | Fable | on demand, and at review tasks | writes the milestone plan into goal checklists; replans; files held findings at milestone end | builds, merges |
| **Runner** | a cheap Claude model | a short run on a timer; stateless | reads labels and reports, moves one owner label or dispatches one role, fires escalation triggers, exits | judges code, changes the plan, reads an issue body |
| **Builder** | Codex | one pass per task, in its own worktree | claims, triages, branches, opens a PR, runs gates, self-reviews, reports | merges |
| **QA** | Claude | a top-level session per PR | cross-review on two axes, live-app check, merges | builds features |
| **Owner** | the human | at gates | answers one gate at a time; approves scope changes | — |

QA may push a fix only inside the PR's own files. Anything larger goes back to
the builder.

**Entry points.** The normal entry is a milestone. An explicit issue list also
works: it runs as a small plan. For one or two issues the list order is the
plan, and the planner is skipped.

## Decisions

1. **Roles are fixed by ecosystem, not alternated per ticket.** Alternating
   builders mixes two idioms in the code, splits guidance across two
   instruction files (`AGENTS.md`, `CLAUDE.md`), and blurs who reviews whom.
   It also makes Claude spend depend on how fast Codex works rather than on a
   choice.
2. **Codex builds and Claude runs QA, by default.** The reason is tooling and
   budget, not a claim about which model codes better. QA needs the live app
   and a browser, and the Codex sandbox could not run the local server. Build
   is the bulk of the tokens, and that subscription was idle. The mapping is
   one config line, so it can be swapped and compared.
3. **The runner is stateless.** GitHub is the only state. The runner re-reads
   it on every run and keeps nothing between runs. The plan must therefore be
   fully written down; nothing lives in a session's memory.
4. **Planning and running are split.** Fable writes the plan and does the
   reviews. A cheaper model walks it with the escalation table.
5. **A milestone is the release boundary: what ships together.** GitHub does
   not order issues inside a milestone. Order lives in the goal issue
   checklists, which already carry order and gates.
6. **Replan authority.** The planner may reorder and split tasks freely. Moving
   anything out of the milestone asks the owner. A split must stay inside the
   parent's stated scope. If the children touch areas the parent did not name,
   that is scope growth and it asks the owner too.
7. **Planner reviews are checklist tasks, not a timer.** At plan time the
   planner places a review task every N tasks or at each phase boundary, and
   scales N to the plan's size and complexity. The runner reaches the task and
   dispatches it like any other. Each review compares the current plan with
   the original and reports what was reordered, split or slipped.
8. **One exclusive owner label per issue. The label is the lock.**
9. **Only QA merges, in the same top-level session that reviewed.** No
   subagent ever runs `gh pr merge`.
10. **Held findings go in the PR body.** The builder and QA list them and
    report a count. Neither files them.
11. **One builder at a time, by default.** #113 fenced explicit issue lists
    into parallel lanes. Here they run serially, like the goal checklist.
    Parallel builders come back later, on swarm's fencing (Open questions).

## Issue state

### Owner labels

An `owner:` label sits beside this repo's `status:` lifecycle. It names which
role holds the issue now. An issue carries at most one.

| Label | Held by | Set when |
|---|---|---|
| `owner: build` | the builder | a task becomes next in the checklist |
| `owner: qa` | QA | the builder reports `ready-for-qa` |
| `owner: human` | the owner | any role posts a gate |
| `owner: plan` | the planner | a review task is reached, or a trigger asks for a replan |

Each role acts only on issues carrying its own label. A role hands an issue on
by swapping the label and commenting why. When a gate clears, the label
returns to the role that posted it.

### Claim lock

The owner label is what the runner reads to choose work. The claim comment is
what settles a race between two passes of the same role. Claiming is step 0 of
every builder pass:

1. **Read.** Read the issue's labels and its claim comments.
2. **Stop if claimed.** If a live claim exists, stop with `stopped: claimed`.
3. **Claim.** Otherwise, post a claim comment carrying the signature line and a
   timestamp. Swap `status: ready` for `status: wip`; the claim replaces the
   ready label rather than adding a second `status:` label.
4. **Re-read, earliest wins.** Re-read the claim comments. If an earlier claim
   exists, withdraw yours and stop with `stopped: claimed`. This closes the
   check-then-set race without an atomic primitive.

**Stale claims can be reclaimed.** A claim is stale when there is no linked PR
and no activity on the issue for N hours. The reclaiming pass comments that it
is taking over before it claims. Without this rule, every pass that crashes
leaves its issue stranded under `status: wip` until a human unlabels it.

#113 also had the lane self-assign. That is dropped: every agent posts as the
owner, so an assignment carries no information.

### The `afk` flag

The planner sets `afk` per task at plan time.

- **`afk`**: the harness owns the task end to end, and QA merges.
- **No `afk`**: QA stops with an owner gate instead of merging.

### Signatures

Every comment and PR body a role writes ends with one line:

```
— <role> · <ecosystem>/<model> · <run id>
```

This is cheap and works today. Separate GitHub bot accounts would attribute
work natively, but they add token management. Revisit if signatures prove
insufficient.

### Gates

The gate form carries over from the cross-ecosystem loop:

```
GATE: <short name>
Look:  1. <theme: where to go, what would look wrong>
       2. …
```

For a gate that is a command to run, not something to see: one `Run:` line and
`Then: comment "cleared: <short name>"`. Before posting a gate, a role does
everything it can do itself, so the owner gets one question or one command.
The runner sends a notification for each new gate.

A gate never stops work that does not depend on it.

## Builder pass

1. **Claim** (above).
2. **Triage.** Dispatch a cheap triage subagent before loading anything else,
   so an early stop costs a near-empty context. It applies the finish-alone
   test (`swarm/SKILL.md`): acceptance criteria the builder can check itself,
   and a scope boundary naming what the task is not. It also checks sub-issues
   and `blocked_by` links. That second check matters: a pass that reads only
   its own issue cannot see that the issue is an umbrella over others, and
   would "finish" it by doing every child in one PR.
   - Umbrella → stop with `stopped: umbrella`.
   - Cannot reach agent-ready without a human → post a gate with one question.
3. **Build.** Branch from the base, open a PR, run the gates, self-review on
   two axes, and list held findings in the PR body.
4. **Report** (below) and exit.

**The profile is passed by path.** The dispatch tells the builder to read the
repo's harness profile at `<baseline sha>` for docs, commands and landing
policy. Gate numbers belong to the run, not the repo, so a committed profile's
gate rows are stale by construction. The dispatch carries this run's gate
baseline inline, in two lines.

The builder works in its own worktree. No other role writes in it.

## Report contracts

Fixed shape, about 15 lines at most.

**Builder → runner and QA:**

```
issue: #<n>   status: ready-for-qa | gate | blocked | stopped[: claimed | umbrella | fence | red-gate]
pr: #<m>      base: <sha>   head: <sha>
gates: <gate> <pass>/<total> · <gate> <pass>/<total> · …
review: standards <clean | fixed k> · spec <clean | fixed k>
areas: <areas the PR touched>
design call: <one line, or none>
needs human: <one question, ≤2 lines, or none>
held findings: <k> — listed in PR body
```

`stopped: fence` means the task needs areas the plan did not name. `base` is
carried so QA can diff without the runner reading anything.

**QA → runner:**

```
issue: #<n>   verdict: merged | back-to-build | gate
pr: #<m>      head: <sha>   merge: <sha, or none>
gates at head: <gate> <pass>/<total> · …
live check: pass | gaps <k>
back to build: <k findings, or none>
held findings: <k> — listed in PR body
```

QA merges with the output of `stone-merge`'s `merge-cmd.sh` (#103), including
`--match-head-commit <head>`. That stops a head that moved after QA ran from
landing.

## Delegated reads

Each bulky read becomes a cheap subagent that returns a table or a verdict.

| Step | Role | Subagent reads | Subagent returns |
|---|---|---|---|
| Plan: queue | planner | issue bodies and links | an in/out table, with a one-line reason per issue |
| Plan: areas | planner | issue bodies **and the code**, not titles | task → areas → collisions |
| Milestone start: profile and baseline | runner | the repo, the profile, a gate run | gate numbers at a named commit, blast-radius survivors, and a **drift verdict**: `launch` \| `fix-profile-first` \| `red-baseline` |
| Builder step 0: triage | builder | the issue, sub-issues, `blocked_by` links | ready \| umbrella \| needs-human |
| QA: verify | QA | the PR branch at `head`, against `base` | gates at `<sha>`, and whether the tree is clean |
| Milestone end: verify | runner | the merged base | gate numbers; leftover branches, worktrees or open PRs |
| Milestone end: findings | planner | every merged PR body's held findings, plus `git grep <symbol> <baseline>` | **debris** (this milestone introduced it → a cleanup task) / **pre-existing** (→ a ticket, combined by theme) / **decline** (with reason) |
| Salvage | runner | a stalled builder's worktree | a state summary, a proposed resume point, and the session id needed to resume it |

The drift verdict exists because a bare drift table leaves the reader unable to
judge whether the drift is fatal without reading the repo itself.

Held findings are re-checked at milestone end because a builder saw the code
through its task's scope and may have a finding half right.

## Escalation triggers

The runner will not notice that the plan is wrong, so escalation cannot depend
on its judgment. Every trigger is mechanical.

| Trigger | Goes to |
|---|---|
| Drift verdict `fix-profile-first` or `red-baseline` at milestone start | `owner: human` |
| The same issue passed between build and QA twice | `owner: human` |
| A PR touches areas its task did not name, or the builder reports `stopped: fence` | `owner: plan` |
| The builder or QA reports `blocked` | `owner: human` |
| A builder pass exits with no report | salvage, then re-dispatch or `owner: human` |
| A gate open longer than N hours | a repeat notification |
| Remaining tasks × average cycle time exceeds the time left | `owner: plan`, then the owner |
| A claim with no PR and no activity for N hours | reclaim |
| A review task is next in the checklist | `owner: plan` |

The area trigger needs each task to name its areas. The planner writes them at
plan time.

## Budget

Build tokens go to Codex. Claude tokens go to three places: planning (Fable,
occasional), the runner (a cheap model, short runs, about 5k per ticket), and
QA (one session per PR). The merge must not load the full `stone-merge` body;
#103 splits it so QA calls `merge-cmd.sh` instead.

## Relation to existing work

- **#113, thin-orchestrator.** Folded in here and superseded. Kept: the
  transcript evidence, pointers not content, the 5k target, the claim lock,
  the report contract, delegated reads, the drift verdict, held findings, and
  the handoff hook. Changed: swarm lanes of one model become roles across two
  ecosystems; merges move from the main session to the QA session;
  explicit lists run serially; self-assign is dropped.
- **#103, split `stone-merge`.** Still a prerequisite. Its `merge-cmd.sh`,
  `ready.sh`, `watch.sh` and `cleanup.sh` are reused by QA and the builder.
- **`/swarm`.** Keep it until one milestone ships through the harness. Then
  deprecate it, or keep it only for parallel batch work that has no release
  shape. Its fencing is the starting point for parallel builders.

## Scope

0. **Prerequisite: #103.**
1. **Conventions, written once.** Owner labels, the `afk` meaning, signatures,
   the claim comment, the gate form and both report contracts, in one place
   that every role's brief points to. This fixes "three documents that
   disagree."
2. **Builder driver.** Generalize the Codex loop driver: claim, triage,
   profile by path with the inline baseline, one pass per task, the report
   contract, exit codes, and a worktree no other role writes in.
3. **QA driver.** A top-level Claude session per PR: verify, review, live-app
   check, merge, record. Blocked on the open question about unattended merges.
4. **Runner.** Stateless, on a timer, with the escalation table, the
   milestone-start drift check, milestone-end verify, and salvage.
5. **Planner skill.** Turns a milestone into ordered goal checklists, with
   named areas and the `afk` flag per task, review tasks placed by plan size,
   and the findings filer at milestone end.
6. **Explicit-issue entry.** An issue list runs as a small plan.
7. **Handoff reader hook, for judgment work.** Independent of the harness; can
   ship any time. A `SessionStart` hook finds the newest handoff and prints its
   path plus its first three lines, never the body. It finds the handoff
   either by a location the user sets once or by searching the temp directory
   for the newest handoff-shaped file; that is the implementation's call. The
   upstream `/handoff` skill is untouched. The habit that pays off is leading a
   handoff with tracker pointers (issues, PRs, SHAs) rather than restating
   them.

**Pilot** on one milestone in a real repo. Measure:

- Owner turns per task. Target: gates only; for an `afk` task, none beyond the
  trigger.
- Passes between build and QA per task.
- Runner tokens per ticket, from the transcripts' `usage` fields. Target: ≤5k.
  Record the dispatch size separately; it is the item most likely to blow the
  budget.
- Claude tokens per task, against Codex tokens per task.
- Calendar time from plan to milestone closed.

## Resolved in review

An adversarial review of #113 settled these, and they still hold:

- **Held findings** live in the PR body. A filer at the end re-checks them and
  files them, so swarm's re-check against the code survives.
- **Claim atomicity** comes from the earliest-wins claim comment. The same
  comment is needed anyway for stale-claim recovery.
- **Triage** stays inside the builder pass, as its own cheap subagent, run
  before the pass loads anything.
- **Handoff delivery** is hook-only.

## Open questions

- **Which ecosystem is better at build, and which at QA?** Not settled. The
  default follows tooling and budget. A second pilot could swap the roles for
  one milestone and compare passes between build and QA, and defects found
  after merge.
- **Should QA write the failing tests first?** QA could write acceptance tests
  from the spec before the builder starts. That is a stronger check, because
  the builder cannot grade its own work. It costs Claude tokens up front and
  adds a handoff per task.
- **Can a scripted top-level Claude session merge unattended after its own
  review?** Verify this under the auto-mode classifier before Scope item 3. If
  it cannot, QA stops at "ready to merge" and the owner's session merges. This
  must be a session designed to merge from the start. It must never be a way
  around a merge that a subagent was denied.
- **Verifier duplication.** QA re-runs gates the builder just ran. Is there a
  cheaper independent check — CI status at `head` plus a tree-clean probe —
  that keeps "a report is a claim" without a second full gate run? The live
  check in the other ecosystem stays either way.
- **Is the 5k target real?** Measure it in the pilot. If the dispatch plus the
  report plus the verdict already sits near 4k, revise the target rather than
  the design.
- **Parallel builders.** One builder at a time is the safe default. Two
  builders on disjoint areas would need swarm's fencing. Defer until the pilot
  shows the builder is the bottleneck.
- **Thresholds.** The runner interval, the gate reminder, and the stale-claim
  time. The stale-claim time must exceed the longest plausible builder pass,
  gates and CI included, on a slow repo, or a live pass gets reclaimed.
- **Where it lives.** Skills and driver scripts here. A per-repo harness
  profile holds the gates, the serve command and the QA checks; swarm's
  `PROFILE.md` is the starting point.

## Out of scope

- Judgment flows and their `/clear` + `/handoff` cadence, apart from the
  reader hook.
- Ranking models by benchmark.
- Releases that span more than one repo.
- Caps on spend, depth or fan-out.
- Fixing any one repo's profile or lifecycle-doc drift. The harness catches
  drift; the repo fixes its own docs.
