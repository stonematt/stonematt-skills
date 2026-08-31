---
name: swarm
description: "Swarm a ticket queue to done unattended — file-fenced lanes of agents landing issues in parallel. Use when the user says swarm it, or wants open issues worked while they're AFK."
---

A **lane** is one agent that owns a set of **files**, not a set of issues. Lanes run in parallel; items inside a lane run serial. The fence is what makes the run unattended — two agents that never touch the same file never conflict, so nobody has to be awake to referee.

## 1. Build the queue

Read every open issue. Each lands in-queue or out-with-a-reason.

In-queue means the ticket is a spec an agent can finish alone: acceptance criteria it can check itself, and a scope boundary naming what it is not. Out means a parent spec, a map, or anything needing a device, a credential, or a human eye in the loop.

The repo's agent-ready label narrows the list; it does not decide it. A parent spec can carry the label and still be the umbrella over the very issues you just queued. Apply the finish-alone test to every labelled issue.

**Done when** the user has both lists, and the out-list says why for each.

## 2. Fence the lanes

Map each queued issue to the files it will edit — from the issue bodies and the code, not from whatever handoff sent you here. Group by collision: same file, same lane. Test files collide as hard as source files; a shared test module is the collision you will miss.

Serial inside a lane is the point, not a compromise — three issues in one file, run parallel, manufacture the conflicts the fence exists to prevent.

No collisions at all is one lane with no fence.

**Some changes cannot be fenced.** A rename, a signature change, a vocabulary fix touches every lane's files at once. The file rule offers two exits — collapse every lane into one, or drop the issue. Take the third: give the fence a time dimension. That issue becomes its own lane, launched once the others have merged. Sequence it, don't fence it.

Watch for a collision you can only dissolve by pre-deciding a ticket's design fork. Sometimes the ticket's acceptance criteria already force that answer and you are merely reading it early. Check which before you constrain a lane, and say so.

**Done when** every queued issue sits in exactly one lane, no file appears in two lanes running *at the same time*, and any sequenced lane names what it waits on.

## 3. Pin the profile

Everything one repo answers once — gates, sync, docs, verbs, landing policy — goes in [`PROFILE.md`](PROFILE.md), and every lane inherits the same filled copy. A repo that already keeps one at `.claude/swarm-profile.md` hands you most of it; read it against the repo before you trust it, since it was true whenever it was written.

Run the repo's **gates** on the base branch; record the commit and the numbers. Gates are whatever that repo calls pre-merge — `AGENTS.md` / `CLAUDE.md` name them.

A red baseline stops the swarm. Report it; lanes launched onto broken ground just distribute the breakage.

Then measure the gates' **blast radius** — what they touch outside a worktree, for real, on every lane, unattended.

**Probe it; reading the source gets this wrong both ways.** A fixture can neutralise a call that looks lethal, and a helper three modules down can reach a live path nothing in the tests names. So plant a marked file in each directory a gate could plausibly reach — the temp root, the home config dir, any live data dir — run the whole gate set on the base branch, and see which markers survive. What dies is the blast radius; what survives is a suite that sandboxes itself.

Name the destructive scripts the lanes are to leave unrun, and say what each one touches. A script that is not a gate is still one command away from a lane trying to be thorough.

**Done when** the profile has every field filled, and its filled copy is in the repo at `.claude/swarm-profile.md`.

## 4. Launch

One `Agent` per lane, `subagent_type: general-purpose`, `model: opus`, briefed from [`LANE-BRIEF.md`](LANE-BRIEF.md).

Hold the objective in the task list — goal, scope, baseline, stop condition, one task per lane. An unattended run outlives its context window, and the task list is what survives a compaction.

**Done when** every lane is running and the user has the table: which issues, which files, which order.

## 5. Verify independently

A lane report is a claim. Run the gates yourself and read the tree.

Lane gate numbers are often measured mid-branch, before the lane's last commits. Yours are the ones that count.

**Done when** you have personally confirmed: gates green at a named commit, no open PRs, no leftover `fix/*` branches **local or remote**, worktrees back to baseline, and every issue named beside its PR number and merge commit.

## 6. Clear the debris, then file the rest

Sort every finding the lanes reported into two piles: what this swarm introduced, and what was already there. Verify with `git grep <symbol> <baseline-commit>` — "absent at baseline" is the test, not memory.

**Debris the swarm made, the swarm clears.** A dead branch, a duplicated primitive, a default that reintroduces the bug just fixed, a sibling caller left on the old shape. The lane that saw it could not reach it — the fence had it — but the fence dissolves the moment the lanes finish. Fix it in one cleanup lane off the merged base, and land that too. A run that closes five issues and opens five for its own leavings has moved nothing.

**Pre-existing findings become tickets.** Check each against the code first; the lane saw it through its own fence and may have it half right. Combine them — related findings in one ticket with the split rationale demoted to acceptance criteria, not one ticket per line number.

**Done when** the cleanup lane is merged and every remaining finding is a ticket number or a stated decline.

## Salvage a stalled lane

Lanes die — a watchdog timeout, a stream that does not recover. Unattended, this surfaces at step 5 as an issue that simply never landed.

**Salvage it.** Read the tree first: `git worktree list`, then `git status` and `git diff` inside that lane's worktree. The work is almost always still sitting there uncommitted. Resume the agent from its transcript, with a message naming what you found on disk and where to pick up — its context is intact, and re-deriving it is the expensive part a fresh agent would pay twice.

## Escalation

A lane stops rather than crossing its fence or relaxing an acceptance criterion. Relay each escalation when it lands — the other lanes keep running, and a ticket that turns out unsatisfiable is the user's call to re-spec.
