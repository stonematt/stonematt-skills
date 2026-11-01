# Swarm console data contract

What the console reads, and what each part of the page comes from. Read it before you change what the [`swarm`](../swarm/SKILL.md) skill writes or what the console draws: a change on one side that the other does not read is a page that quietly goes blank. The [`swarm-board`](../swarm-board/README.md) mod reads the same link descriptions, status lines and run-log `Session:` line, the run log's title as the goal, and the Lanes block's ticks: keep it in step too.

## Done

Four things finish in a swarm, and each one has one signal. The swarm writes these signals, and the console and the board read them. Neither one infers "done" any other way.

| What | Done when | Signal |
|---|---|---|
| **Ticket** | Its PR merges, by the orchestrator's `gh pr merge`, into the run's `<base>` | The merge call, paired to the ticket (below) |
| **Link** | Its one ticket merged (or closed with no PR) and it cleaned up (lane brief step g) | The link's `swarm: queue-done` status line |
| **Lane** | Every ticket on its Lanes-block line is done | The orchestrator ticks the line `- [x]` |
| **Run** | Swarm step 5 passes and the owner says their review is done | The run log's closing totals (swarm step 7) |

A lane is done the way a merged ticket is: true now, and changed only by adding a ticket. A UAT finding, a review finding or a red gate becomes a new ticket on some lane's line. That un-ticks the lane, and the lane runs again until the new ticket merges. Every piece of work has its own ticket. A merged ticket never takes new work under its number.

The console shows a lane done when every ticket on its line has merged by the moment on screen. It also shows it done when the line is ticked and the lane's last link ended `queue-done`. That second case covers a ticket that closes with no PR, such as a review-only ticket. The plan is read as it is now, so in a replay the hand-back dates the tick. The board shows a lane done only when its line is ticked. A finished link of an unticked lane is between links, so the lane still counts as running. Without a Lanes block, both fall back to the link's own state.

## Ticket and PR

Which issue a PR lands comes from, in order: the lane's status line `swarm: ready-to-merge issue=<n> pr=<m>`, the Lanes block's `Merged:` line, and the PR body's `Closes #<n>` lines. A branch ending `-<n>` counts only for a PR none of those name. That fallback is for sessions from before the status line.

## What the swarm writes

The console infers the rest from habits the swarm skill already has; each one feeds a part of the page.

| The swarm does | The console shows |
|---|---|
| Describes each link `Lane <X>: #<n> (<k>/<total>) <objective>` and names it `lane-<x>-<k>` (swarm step 4) | One board row per lane, every link folded in: its queue, its objective beside the lane name, merged out of `<total>`; resumes and next links on edges and in the lane zoom. In the graph, the lane's links chain off its node in launch order. Older `Lane <X>: #<n>→#<n>` descriptions still read as one lane each. The session list shows only sessions with at least one such link. |
| Opens every lane turn with the status line ([`LANE-BRIEF.md`](../swarm/LANE-BRIEF.md) "Status line") | The **Needs you** bay and the tag on the lane's card. Sessions from before the status line fall back to keywords in the hand-back. |
| Runs every `gh pr merge` from the orchestrator | Tickets moving to Merged, merge diamonds, PR links |
| Titles the run log with the goal and ticks its `- [ ]` lines | The Goal panel. Older sessions' `TaskCreate` / `TaskUpdate` goal task still shows as it stood at each moment. |
| In a goal swarm, writes `Scope: goal/<slug> → <base>` in the run log, and leaves the goal PR for the owner to merge | The landing target in the Goal panel's Scope row. Lane PRs into the goal branch read like any other; the goal PR never shows as a merge, because the orchestrator never runs it. |

## The Lanes block

The swarm keeps its plan in the run log's `## Lanes` block, with a `Session:` line (swarm step 2). The console matches a run log to the session by `Session:`, else by shared tickets, else by when it was written; a log naming another session is never shown.

```
- [x] Lane A (storage reads tell outcomes): #180 #182 — #182 after Lane C
  Files: lookout/storage/storj.py, tests/test_storage_storj.py
  Merged: #180 → PR 203 c751746, #182 → PR 205 2e50f60
```

A lane line's tickets are the `#<n>` before its ` — `. Numbers inside parentheses are never read as tickets, so older logs that put merge notes there still parse. The indented `Merged:` line records each merged ticket's PR and merge commit.

From the block, tickets no link has reached sit in **Queued**, and trail the lane's chain in the graph as dashed squares. A planned lane with no link yet is a **Not started** row, or a **pending** one that names the lanes it waits on. Each `#<n> after Lane <X>` is a faint edge to lane X, so a join draws one edge for each lane it waits on. The header counts lanes running (started and not done) and pending, out of the total.

Without the block, the board shows only what link descriptions name.

## Stage and notices

Stage is inferred from each lane's tool calls: edits and test, lint, type and build commands are **Build**; reviewer subagents, browser tools and dev servers are **Review**; `gh pr create`, `gh pr checks` and `git push` are **PR / CI**. A hand-back keeps the stage it interrupted.

A **notice** sits across stages: a lane handed back with no resume since, or silent for over 10 minutes. It clears on a resume, a merge, or the lane moving again.
