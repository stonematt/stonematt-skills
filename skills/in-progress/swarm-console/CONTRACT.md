# Swarm console data contract

What the console reads, and what each part of the page comes from. Read it before you change what the [`swarm`](../swarm/SKILL.md) skill writes or what the console draws: a change on one side that the other does not read is a page that quietly goes blank.

## What the swarm writes

The console infers everything from habits the swarm skill already has; each one feeds a part of the page.

| The swarm does | The console shows |
|---|---|
| Describes each link `Lane <X>: #<n> (<k>/<total>) <objective>` and names it `lane-<x>-<k>` (swarm step 4) | One board row per lane, every link folded in: its queue, its objective beside the lane name, merged out of `<total>`; resumes and next links on edges and in the lane zoom. In the graph, the lane's links chain off its node in launch order. Older `Lane <X>: #<n>→#<n>` descriptions still read as one lane each. |
| Opens every lane turn with the status line ([`LANE-BRIEF.md`](../swarm/LANE-BRIEF.md) "Status line") | The **Needs you** bay and the tag on the lane's card. Sessions from before the status line fall back to keywords in the hand-back. |
| Runs every `gh pr merge` from the orchestrator, on PRs whose body has `Closes #<issue>` lines (or, failing that, branches ending `-<issue>`) | Issues moving to Merged, merge diamonds, PR links |
| Titles the run log with the goal and ticks its `- [ ]` lines | The Goal panel. Older sessions' `TaskCreate` / `TaskUpdate` goal task still shows as it stood at each moment. |
| In a goal swarm, writes `Scope: goal/<slug> → <base>` in the run log, and leaves the goal PR for the owner to merge | The landing target in the Goal panel's Scope row. Lane PRs into the goal branch read like any other; the goal PR never shows as a merge, because the orchestrator never runs it. |

## The Lanes block

The swarm keeps its plan in the run log's `## Lanes` block, with a `Session:` line (swarm step 2). The console matches a run log to the session by `Session:`, else by shared tickets, else by when it was written; a log naming another session is never shown.

From the block, tickets no link has reached sit in **Queued**, and trail the lane's chain in the graph as dashed squares. A planned lane with no link yet is a **Not started** row, or a **pending** one that names the lanes it waits on. Each `#<n> after Lane <X>` is a faint edge to lane X, so a join draws one edge for each lane it waits on. The header counts lanes running and pending out of the total.

Without the block, the board shows only what link descriptions name.

## Stage and notices

Stage is inferred from each lane's tool calls: edits and test, lint, type and build commands are **Build**; reviewer subagents, browser tools and dev servers are **Review**; `gh pr create`, `gh pr checks` and `git push` are **PR / CI**. A hand-back keeps the stage it interrupted.

A **notice** sits across stages: a lane handed back with no resume since, or silent for over 10 minutes. It clears on a resume, a merge, or the lane moving again.
