---
name: swarm-console
description: "Open the swarm console: a local browser view of a swarm in flight, or a replay of a finished one — lanes by stage, what needs you, a heartbeat per agent. Use when the user asks to open or stop the swarm console, wants to see swarm progress, or when the swarm skill has launched its lanes."
---

The console reads what a swarm already writes — session transcripts, subagent metadata, the run log, the repo's PRs — and serves one page over it for one repo. It writes nothing. A swarm in flight shows live; any past session of the repo replays on a time scrubber.

## 1. Start it, or find it

From the swarm's repo — any worktree of it — run in the background:

```
node <skill-dir>/scripts/swarm-console.mjs [--project <repo-path>] [--runs <run-log-dir>]
```

The script is the record of what runs; nothing about the console belongs in memory. It prints one of:

- `started (pid <pid>) … → <link>` — this session owns that console.
- `reused (pid <pid>) … → <link>` — the repo's console was already up; the script exits.

Each repo gets its own console on its own port, starting at 4186. `--runs` points at the swarm skill's run logs when they live somewhere other than its default.

**Done when** the script has printed a link.

## 2. Open it

Open the link in the browser the user named — on macOS `open -a "Google Chrome" <link>`, or plain `open <link>` for their default — and give them the link. It opens the repo's newest session with subagents; pin a different one with `&session=<id>`, the orchestrator's own session id. `&lane=<agent-id>` zooms to one lane; `&t=<epoch-ms>` reopens a moment, and a paused page writes it into its URL. The page lists its keys under `?`.

**Done when** the user has the link and the page shows the swarm's lanes.

## 3. Stop it

```
node <skill-dir>/scripts/swarm-console.mjs --stop [--project <repo-path>]
```

It finds the repo's console by asking each port who it is, and stops that one. Stop a console this session started, or one the user asks you to stop.

**Done when** the script prints `stopped` or `no swarm console running`.

## Data contract

The console infers everything from habits the [`swarm`](../swarm/SKILL.md) skill already has; each one feeds a part of the page.

| The swarm does | The console shows |
|---|---|
| Describes each link `Lane <X>: #<n> (<k>/<total>) <objective>` and names it `lane-<x>-<k>` (swarm step 4) | One board row per lane, every link folded in: its queue, its objective beside the lane name, merged out of `<total>`; resumes and next links on edges and in the lane zoom. In the graph, the lane's links chain off its node in launch order. Older `Lane <X>: #<n>→#<n>` descriptions still read as one lane each. |
| Keeps the plan in the run log's `## Lanes` block, with a `Session:` line (swarm step 2) | The run log is matched to the session by `Session:`, else by shared tickets, else by when it was written; a log naming another session is never shown. Tickets no link has reached sit in **Queued** and trail the lane's chain in the graph as dashed squares; a planned lane with no link yet is a **Not started** row; `#<n> after Lane <X>` is a faint edge to lane X. Without the block, the board shows only what link descriptions name. |
| Opens every lane turn with the status line ([`LANE-BRIEF.md`](../swarm/LANE-BRIEF.md) "Status line") | The **Needs you** bay and the tag on the lane's card. Sessions from before the status line fall back to keywords in the hand-back. |
| Runs every `gh pr merge` from the orchestrator, on branches ending `-<issue>` | Issues moving to Merged, merge diamonds, PR links |
| Titles the run log with the goal and ticks its `- [ ]` lines | The Goal panel. Older sessions' `TaskCreate` / `TaskUpdate` goal task still shows as it stood at each moment. |
| In a goal swarm, writes `Scope: goal/<slug> → <base>` in the run log, and leaves the goal PR for the owner to merge | The landing target in the Goal panel's Scope row. Lane PRs into the goal branch read like any other; the goal PR never shows as a merge, because the orchestrator never runs it. |

Stage is inferred from each lane's tool calls: edits and test, lint, type and build commands are **Build**; reviewer subagents, browser tools and dev servers are **Review**; `gh pr create`, `gh pr checks` and `git push` are **PR / CI**. A hand-back keeps the stage it interrupted.

A **notice** sits across stages: a lane handed back with no resume since, or silent for over 10 minutes. It clears on a resume, a merge, or the lane moving again.

## Lessons

Notes for the next edit of this skill live in `~/.claude/skill-workbench/swarm-console/`, outside any repo. When the console misleads, breaks, or the user asks for a change you did not make, append a dated entry to `feedback.md` there: what happened, the session it came from, and the line of this skill or its scripts you would change. Read that file before editing the skill.
