---
name: swarm
description: "Swarm a ticket queue to done unattended — file-fenced lanes of agents landing issues in parallel. Use when the user says swarm it, or wants open issues, or a spec or milestone's tickets, worked while they're AFK."
---

A **lane** is one agent that owns a set of **files**, not a set of issues. Lanes run in parallel; items inside a lane run serial. The fence is what makes the run unattended — two agents that never touch the same file never conflict, so nobody has to be awake to referee.

## 1. Build the queue

**First name the run's shape, from what the user pointed you at.** A **goal** swarm works a spec, a milestone, or a goal's list of tickets: a collection that only means something once all of it lands. It lands on a **goal branch** (step 4) and reaches the base branch as one PR the owner reviews. A **queue** swarm works the open issue list, or a one-off batch with no shared goal; each ticket lands on the base branch as its own PR. The shape is on the run's task from here on.

Read every open issue in scope: the goal's tickets, or the whole open list. Each lands in-queue or out-with-a-reason.

In-queue means the ticket is a spec an agent can finish alone: acceptance criteria it can check itself, and a scope boundary naming what it is not. Out means a parent spec, a map, or anything needing a device, a credential, or a human eye in the loop.

The repo's agent-ready label narrows the list; it does not decide it. A parent spec can carry the label and still be the umbrella over the very issues you just queued. Apply the finish-alone test to every labelled issue.

A goal's parent spec or milestone is the goal, not a ticket: out of the queue, and named on the run's task.

**Done when** the user has the run's shape and both lists, and the out-list says why for each.

## 2. Fence the lanes

Map each queued issue to the files it will edit — from the issue bodies and the code, not from whatever handoff sent you here. Confirm every absence a map agent reports with your own `git grep` before it goes into a brief or to the user; a map's "X doesn't exist" becomes a wrong brief.

Group by collision: same file, same lane. Test files collide as hard as source files, and the ones you will miss are the ones that never name your file: a shared test module, a fixture typed by an interface a lane changes (grep the type name), an end-to-end spec elsewhere that finds the component by its role or visible text (grep the tests tree for its strings).

Serial inside a lane is the point, not a compromise — three issues in one file, run parallel, manufacture the conflicts the fence exists to prevent.

No collisions at all is one lane with no fence.

**Count lanes by what runs at the same time.** A lane is a parallel thread: a fence and an ordered queue. Two groups that can only run one after the other are one lane, not two — one queue, in build order. Ten tickets that must land in sequence are one lane with ten tickets. A long queue does not cost a long context; each ticket gets a fresh agent (step 4).

**Some changes cannot be fenced.** A rename, a signature change, a vocabulary fix touches every lane's files at once. The file rule offers two exits — collapse every lane into one, or drop the issue. Take the third: give the fence a time dimension. That issue goes last: it waits for every other lane to merge, then runs as the final ticket of one of them. Sequence it, don't fence it. In a queue swarm, a hub file that every ticket touches gets the same answer: one lane, its tickets in build order.

**A goal swarm lanes by the frontier, not the fence.** Its tickets carry `blocked-by` edges (`/to-tickets` writes them as native GitHub links; read them with `gh api repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by`), and those edges set the lanes. Every ticket unblocked at the same moment runs at the same time, hub file or not. When a ticket merges, the first ticket it unblocks continues its lane as the next link; each other newly unblocked ticket opens a new lane. A ticket blocked by two lanes waits for both and continues the later one. The goal branch is what makes the shared files safe: lanes rebase onto it before they hand back, and your gate run after each merge (step 4) catches the semantic breaks git merges clean. Keep the fence only on files that cannot merge by rebase: a schema and its migrations, a lockfile, a generated file. Tickets that touch one of those share a lane, in build order.

Watch for a collision you can only dissolve by pre-deciding a ticket's design fork. Sometimes the ticket's acceptance criteria already force that answer and you are merely reading it early. Check which before you constrain a lane, and say so.

**Done when** every queued issue sits in exactly one lane, no fenced file appears in two lanes running *at the same time* (every file, in a queue swarm), no two lanes run strictly one after the other, a goal swarm runs as many lanes as its widest frontier, and each lane is a task in the task list — its objective, its issues in order, its files, and any lane it waits on as a blocker. One more task holds the goal, scope and stop condition. An unattended run outlives its context window, and the task list is what survives a compaction.

## 3. Pin the profile

Everything one repo answers once — gates, sync, docs, verbs, landing policy — goes in [`PROFILE.md`](PROFILE.md), and every lane inherits the same filled copy. A repo that already keeps one at `.claude/swarm-profile.md` hands you most of it; read it against the repo before you trust it, since it was true whenever it was written.

Run the repo's **gates** on the base branch; record the commit and the numbers. Gates are whatever that repo calls pre-merge — `AGENTS.md` / `CLAUDE.md` name them.

A red baseline stops the swarm. Report it; lanes launched onto broken ground just distribute the breakage.

Then measure the gates' **blast radius** — what they touch outside a worktree, for real, on every lane, unattended.

**Probe it; reading the source gets this wrong both ways.** A fixture can neutralise a call that looks lethal, and a helper three modules down can reach a live path nothing in the tests names. So plant a marked file in each directory a gate could plausibly reach — the temp root, the home config dir, any live data dir — run the whole gate set on the base branch, and see which markers survive. What dies is the blast radius; what survives is a suite that sandboxes itself.

Name the destructive scripts the lanes are to leave unrun, and say what each one touches. A script that is not a gate is still one command away from a lane trying to be thorough.

Split servers in two. A server the owner runs — the main checkout's, on its port, against its data — is leave-unrun. A lane's **own server** is not: where the repo can serve one checkout on its own port and its own database, record the command that starts it from a worktree, how it gets env without copying a secrets file, and how it stops. UI lanes serve their branch with it and critique what they see (`LANE-BRIEF.md` step d), so the owner is not the first one to look.

**Done when** the profile has every field filled, its filled copy is in the repo at `.claude/swarm-profile.md`, and the baseline is on the run's task.

## 4. Launch

**A goal swarm cuts its goal branch first.** If the repo's docs or memory record a decision against goal branches — epics land ticket by ticket, say — ask the owner before you cut one, and run it as a queue swarm if they say no. Branch `goal/<slug>` off the profile's base branch and push it. Make the slug words with no digits: the console reads any `-<digits>` as an issue number. After the first lane merge, open a draft **goal PR** from it into the base branch (GitHub refuses a PR from a branch with no commits): the goal in its title, a `Closes #<n>` line for every queued ticket (`stone-merge` reads them to stage each one when it lands), and a pointer to the spec or milestone. Add `Scope: goal/<slug> → <base branch>` to the goal task's description; the console's Goal panel shows it.

From then on the goal branch is the `<base>` in every lane brief: lanes branch off it, open their PRs into it, and the cleanup lane lands there too. The base branch is untouched until the owner lands the goal PR. A queue swarm skips all this; its lanes' `<base>` is the base branch itself.

**A lane runs as a chain of agents, one per ticket.** Each **link** is a fresh `Agent`, `subagent_type: general-purpose`, briefed from [`LANE-BRIEF.md`](LANE-BRIEF.md) with a queue of one ticket (or the tickets that land as one PR). Launch a lane's next link when the last one hands back `queue-done`. Its brief carries what the earlier links left — new modules, helpers, shared components — so it extends their work instead of rebuilding it. One agent working a whole queue runs its late tickets on a compacted memory of its early ones; a fresh link per ticket keeps each one small. Mark each lane's task in progress as its first link launches.

**Make the run legible.** Describe each link `Lane <X>: #<n> (<k>/<total>) <objective>` — its ticket, its place in the lane's queue, and the lane's objective — and give it `name: lane-<x>-<k>`; resume it by that name. The console folds a lane's links into one row. That holds for every link launched mid-run too — fix links, UAT findings, the cleanup lane: it continues its lane's letter, or takes the next unused one. Never reuse another lane's letter, and never drop the ticket number. The [`swarm-console`](../swarm-console/SKILL.md) skill reads both, plus each lane's status line, your `gh pr merge` calls and the goal task — serve it once the lanes are running and give the user its link.

**Declare every lane's objective.** The objective is two to four words saying what the lane changes: `Lane H: #528 (2/4) club admin forms`, not `Lane H: #528`. It is the lane's, so every link carries the same one. The console prints it beside the lane name; without it the user sees a letter and an issue number, and has to open the issue to learn what the lane is doing. Name the change, not the order — `after G` belongs on the lane's task, where its blocker already sits. Write the objective once in step 2, on the lane's task, and copy it into the description at launch.

**Act on each lane's status line**, the first line of every lane turn ([`LANE-BRIEF.md`](LANE-BRIEF.md) "Status line"): `ready-to-merge` → run the merge, below; `escalation` → relay it, per **Escalation**; `queue-done` → verify the link's merge, then launch the lane's next link, or mark the lane's task complete after its last.

**Where you sit decides the worktree recipe.** From the main checkout, lanes build sibling worktrees (`LANE-BRIEF.md` step a). When you yourself run inside a worktree, a guard refuses that recipe for you and every subagent alike; launch each link with `isolation: "worktree"` and brief it the isolated variant.

**A browser tool is shared by the session.** One Playwright MCP is one browser for every lane, and two lanes critiquing at once resize it under each other. Brief UI lanes to take turns with it, or to drive their own headless browser.

**Pick each lane's `model` from its queue, not from habit.** A lane runs `opus` when its tickets turn on a design fork, a refactor that crosses modules, or a review that has to argue with its own acceptance criteria. A lane runs `sonnet` when the work is mechanical — a doc fix, a rename the ticket already spells out, a test that only needs writing down. The model is a per-lane call because the queues differ; one setting for the whole swarm is the habit, not the judgment.

Wrong-way errors are not symmetric. A `sonnet` lane that needed `opus` surfaces at step 5 as work to redo, and redoing it costs more than the model ever saved. When a queue is mixed, or you cannot tell, take `opus`.

**You run every `gh pr merge`.** A lane takes the merge verb to readiness and ends its turn with the command (`LANE-BRIEF.md` step f). Take the head SHA from `gh pr view <n> --json headRefOid`, not from the lane's report. Merge, then resume that lane with `SendMessage` carrying the merge SHA; it picks up at its step g. The reason is the classifier: it denies a subagent's merge call and allows yours, so a lane that tries it stalls the run. Staying awake for that is the orchestrator's job anyway; verifying (Section 5) already assumed it.

**Key every merge on `gh pr view` state, never on the latest message.** A resume can show "queued" instead of "Resuming", and a stale or duplicate hand-back then arrives after the merge it asked for. When a resume shows "queued", check the remote branch for progress before you resend.

**On a goal branch, run the gates after every merge.** Each lane's gates ran on its own branch, before the merge. Two lanes can each be green and still break each other: one lane's new constraint fails a test in another lane's file, and git merges both clean. Run the profile's gates on the goal branch at the new merge commit, in a scratch worktree made with `git worktree add --detach`, before you resume the lane. Green → resume it. Red → hold every other `ready-to-merge` and launch one **fix link** off the goal branch: the next link of the lane whose merge went red, carrying that lane's ticket number in its description and branch so the console folds it into the lane, fenced to the files the failure names, with the failing output as its ticket. It lands like any link, and the held merges follow it. Log each red one as an incident. A goal branch is often CI-dark (the profile's **CI** row), so these runs are the only check the merged whole gets before the goal PR.

**Keep the run log from the first launch.** The skill improves only from what a run records. Create `~/.claude/skill-workbench/swarm/runs/<YYYY-MM-DD>-<repo>.md` and append one line the moment each **incident** happens: a human had to act (merge, permission prompt, re-spec), a classifier denial (verbatim command), a stall and its salvage, an escalation, a merge conflict, a lane redone at step 5. Each lane completion notification carries `subagent_tokens`, `tool_uses` and `duration_ms` — copy them into the log when it lands, with the lane's model.

**Done when** every lane is running, the run log exists, and the user has the table: which objective, which issues, which files, which order, which model.

## 5. Verify independently

A lane report is a claim. Run the gates yourself and read the tree.

Lane gate numbers are often measured mid-branch, before the lane's last commits. Yours are the ones that count.

When the run changed UI, serve the merged base locally and open every changed page yourself before the owner is asked to look; then give them the link.

**Review the whole, once.** Each lane's review saw only its own diff, so none of them can see what the lanes duplicate or contradict between them: two helpers for one job, two rules for one tiebreak. Once the cleanup lane (step 6) lands, run the profile's **review** verb over the run's whole diff — the goal branch against its base, or for a queue swarm, the base branch from the baseline commit to now. Land its findings as one more link, like any other.

**Then the owner tries it.** Hand the owner the assembled result in whatever form they judge it — a served page, a command to run, a file to open — and say that their review happens here. Their findings are part of the run, not follow-ups: in a goal swarm each one becomes a ticket on the goal (a `Closes #<n>` line on the goal PR) and runs as the next link, gated and merged like the rest; in a queue swarm each one is a new ticket, queued like any other. Repeat until the owner says they are done.

A goal swarm verifies the goal branch. When the owner says their review is done, mark the goal PR ready with `gh pr ready`, watch its CI to a result, and put the PR's link in front of the owner. Landing it is the owner's call, through `stone-merge` or by hand; you leave the goal PR unmerged.

**Done when** you have personally confirmed: gates green at a named commit, no open PRs except a goal swarm's goal PR, no leftover `fix/*` branches **local or remote**, worktrees back to baseline, changed pages seen on a local server, and every issue named beside its PR number and merge commit. Mark each lane's task complete as its merges pass this check.

## 6. Clear the debris, then file the rest

Sort every finding the lanes reported into two piles: what this swarm introduced, and what was already there. Verify with `git grep <symbol> <baseline-commit>` — "absent at baseline" is the test, not memory.

**Debris the swarm made, the swarm clears.** A dead branch, a duplicated primitive, a default that reintroduces the bug just fixed, a sibling caller left on the old shape. The lane that saw it could not reach it — the fence had it — but the fence dissolves the moment the lanes finish. Fix it in one cleanup lane off the merged base (a goal swarm's goal branch), and land that too. A run that closes five issues and opens five for its own leavings has moved nothing.

Dead code cascades: removing one structure leaves its inputs with no reader. Brief the cleanup lane to clear the whole chain in one PR, then grep each removed symbol's former inputs once more after its diff.

Debris that needs an owner's wording or design call — which of two near-identical prompts to keep — is not cleanup. It becomes a ticket that names the swarm PR that caused it.

**Pre-existing findings become tickets.** Check each against the code first; the lane saw it through its own fence and may have it half right. Combine them — related findings in one ticket with the split rationale demoted to acceptance criteria, not one ticket per line number.

**Done when** the cleanup lane is merged and every remaining finding is a ticket number or a stated decline.

## 7. Retro

Close the run log with the totals: issues closed, debris items from step 6, incidents by kind, and for each lane its model, tokens, duration, and whether step 5 made it redo work. Append one JSON line per lane and one for the run to `~/.claude/skill-workbench/swarm/runs.jsonl`, using the fields in the workbench `README.md`.

Then sort every incident by where its lesson lives. A fact about this repo — a gate, a script to leave unrun, a slow sync — goes into `.claude/swarm-profile.md`. A lesson any repo would hit goes into `~/.claude/skill-workbench/swarm/feedback.md` as a dated entry: what happened, the run it came from, and the line of this skill you would change. Project memory is the wrong home for either; a lesson parked there never reaches the next repo.

**Done when** the run is in `runs.jsonl`, every incident is in the profile or in `feedback.md`, and the user has the feedback entries.

## Salvage a stalled lane

Lanes die — a watchdog timeout, a stream that does not recover. Unattended, this surfaces at step 5 as an issue that simply never landed.

**Salvage it.** Read the tree first: `git worktree list`, then `git status` and `git diff` inside that lane's worktree. The work is almost always still sitting there uncommitted. Resume the agent from its transcript, with a message naming what you found on disk and where to pick up — its context is intact, and re-deriving it is the expensive part a fresh agent would pay twice. Log the stall, its cause, and whether salvage worked.

## Escalation

A lane stops rather than crossing its fence or relaxing an acceptance criterion. Relay each escalation (a lane's `escalation` status line) when it lands — the other lanes keep running, and a ticket that turns out unsatisfiable is the user's call to re-spec.
