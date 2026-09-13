# Loop Harness — Brief

Take one release milestone to done in a short window, with the owner steering
and not in the loop. One AI ecosystem builds. The other runs QA and merges. A
planner writes the plan once, a cheap runner walks it, and the owner is asked
only at named gates.

This replaces `/swarm` (`skills/in-progress/swarm/`) for release work. It builds
on the thin-orchestrator brief (#113). The claim lock, the report contract and
"pointers, not content" carry over from there. What is new: fixed build and QA
roles across two ecosystems, a split between planning and running, and
milestones with ordered goal checklists.

**Status:** draft. Nothing here is built yet.

## Origin

### What ran

One app repo ran a Codex loop driver next to the owner's interactive Claude
session. The driver ran `codex exec` once per pass against one goal issue.
Each pass took the first unchecked, ungated task in the goal checklist. It cut
a branch, opened a PR, reviewed it on two axes (Standards and Spec), merged
it, and ended with a `STATUS:` line: `continue`, `gate`, `done`, `blocked`, or
`handback <pr>`.

`handback` existed because the Codex sandbox could not run the local server.
Codex left the PR open. The driver polled for the merge for up to 2 hours. The
owner's Claude session ran the QA pass with its browser tools, merged, and
recorded the task. Anything still uncertain became an owner gate with a
`Look:` list.

### What worked

- **A serial goal checklist.** One builder, one task at a time, so there were
  no collisions and no need for fencing.
- **Cross-model QA.** A different model reviewed the work than the one that
  wrote it.
- **The gate form.** A `Look:` list tells the owner where to go and what would
  look wrong, not a yes/no checklist.

### What did not

- **Nothing claims an issue.** Overlap with the owner's other AFK work was
  avoided only by exclusion lists ("that issue is Codex's").
- **Every comment posts as the owner.** GitHub cannot tell which agent did what.
- **The QA side is a person's session, not a loop.** If the owner is away, the
  2-hour wait runs out and the driver exits. The milestone stalls.
- **Merge authority differs by agent.** Codex merged its own PRs. Swarm lanes may
  not merge. The rules were written in three documents that disagree.
- **A shared worktree.** The driver ran `git reset --hard` in a worktree the QA
  session also worked in. Unpushed QA edits would be lost.

`/swarm` itself was invoked zero times in the window #113 measured.

## Goal

- Ship a milestone in a short window without side quests.
- Keep the owner steering: they set scope and answer gates, nothing else.
- Protect Claude budget. Move build tokens to an otherwise idle Codex
  subscription.

## Roles

| Role | Default | Runs as | Does | Never |
|---|---|---|---|---|
| **Planner** | Fable | on demand, and at review tasks | writes the milestone plan into goal checklists; replans | builds, merges |
| **Runner** | a cheap Claude model | a short run on a timer; stateless | reads labels, moves one owner label or dispatches one role, fires escalation triggers, exits | judges code, changes the plan |
| **Builder** | Codex | one pass per task | branch, PR, gates, self-review, then hands to QA | merges |
| **QA** | Claude | a top-level session per PR | cross-review on two axes, live-app check, merges | builds features |
| **Owner** | the human | at gates | answers one gate at a time; approves scope changes | — |

QA may push a fix only inside the PR's own files. Anything larger goes back to
the builder.

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
   it on every run and keeps nothing between runs. This means the plan must be
   fully written down; nothing lives in a session's memory.
4. **Planning and running are split.** Fable writes the plan and does the
   reviews. A cheaper model walks it with an escalation guide.
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
8. **One exclusive owner label per issue. The label is the lock.** See below.
9. **Only QA merges, and it merges in the same session that reviewed.**

## Issue state

### Owner labels

An `owner:` label sits beside this repo's `status:` lifecycle. It names which
role holds the issue now. An issue carries at most one.

| Label | Held by | Set when |
|---|---|---|
| `owner: build` | the builder | a task becomes next in the checklist |
| `owner: qa` | QA | the builder opens a ready PR |
| `owner: human` | the owner | any role posts a gate |
| `owner: plan` | the planner | a review task is reached, or a trigger asks for a replan |

Each role acts only on issues carrying its own label. A role hands an issue on
by swapping the label and commenting why. When a gate clears, the label
returns to the role that posted it.

Claiming uses #113's rule: a claim comment, earliest claim wins, and stale
claims can be reclaimed. The owner label is what the runner reads. The claim
comment is what settles a race.

### Signatures

Every comment and PR body a role writes ends with one line:

```
— <role> · <ecosystem>/<model> · <run id>
```

This is cheap and works today. Separate GitHub bot accounts would attribute
work natively, but they add token management. Revisit if signatures prove
insufficient.

### Gates

The gate form carries over unchanged:

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

## Escalation triggers

The runner will not notice that the plan is wrong, so escalation cannot depend
on its judgment. Every trigger is mechanical.

| Trigger | Goes to |
|---|---|
| The same issue passed between build and QA twice | `owner: human` |
| A PR touches areas its task did not name | `owner: plan` |
| The builder or QA reports `blocked` | `owner: human` |
| A gate open longer than N hours | a repeat notification |
| Remaining tasks × average cycle time exceeds the time left | `owner: plan`, then the owner |
| A claim with no PR and no activity for N hours | reclaim, per #113 |
| A review task is next in the checklist | `owner: plan` |

The second trigger needs each task to name its areas. The planner writes them
at plan time.

## Budget

Build tokens go to Codex. Claude tokens go to three places: planning (Fable,
occasional), the runner (a cheap model, short runs), and QA (one session per
PR). The runner follows #113's working rule: it never runs a command whose
output it did not ask to have summarized, and it never reads an issue body
itself.

## Relation to existing work

- **#113, thin-orchestrator.** Carries over: the claim lock, the report
  contract, pointers not content, the independent verifier. Differs: #113
  extends swarm with lanes of one model and merges held by the main session.
  This harness replaces swarm for release work, with roles across two
  ecosystems and merges held by QA.
- **#103, split `stone-merge`.** Still a prerequisite. QA reuses
  `merge-cmd.sh` so it does not load the full merge skill on every PR.
- **`/swarm`.** Keep it until one milestone ships through the harness. Then
  deprecate it, or keep it only for parallel batch work that has no release
  shape.

## Scope

0. **Prerequisite: #103.**
1. **Conventions.** Owner labels, signatures, the claim comment, and the gate
   form, written once in one place that every role's brief points to. This
   fixes "three documents that disagree."
2. **Builder driver.** Generalize the Codex loop driver: one pass per task,
   the `STATUS:` contract, exit codes, and a worktree no other role writes in.
3. **QA driver.** A top-level Claude session per PR: review, live-app check,
   merge, record. Blocked on the open question about unattended merges.
4. **Runner.** Stateless, on a timer, with the escalation table.
5. **Planner skill.** Turns a milestone into ordered goal checklists, with
   named areas per task and review tasks placed by plan size.

**Pilot** on one milestone in a real repo. Measure:

- owner turns per task (target: gates only)
- passes between build and QA per task
- Claude tokens per task, against Codex tokens per task
- calendar time from plan to milestone closed

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
  review?** Verify this under the auto-mode classifier before step 3. If it
  cannot, QA stops at "ready to merge" and the owner's session merges. This
  must be a session designed to merge from the start. It must never be a way
  around a merge that a subagent was denied.
- **Parallel builders.** One builder at a time is the safe default. Two
  builders on disjoint areas would need swarm's fencing. Defer until the pilot
  shows the builder is the bottleneck.
- **Thresholds.** The runner interval, the gate reminder, and the stale-claim
  time. The stale-claim time must exceed the longest plausible builder pass.
- **Where it lives.** Skills and driver scripts here. A per-repo profile holds
  the gates, the serve command and the QA checks; swarm's `PROFILE.md` is the
  starting point.

## Out of scope

- Judgment flows: grilling, interviews, wayfinder, to-spec. They keep their
  own cadence.
- Ranking models by benchmark.
- Releases that span more than one repo.
