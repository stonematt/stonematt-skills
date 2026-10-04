---
name: swarm-console
description: "Watch a swarm in flight, or replay a finished one, in a local browser console: lanes by stage, what needs you, a heartbeat per agent. Use when the user wants to see swarm progress, or when the swarm skill has launched its lanes."
---

The console reads what a swarm already writes — session transcripts, subagent metadata, the run log, the repo's PRs — and serves one page over it. It writes nothing. A swarm in flight shows live; any past session replays on a time scrubber.

## 1. Serve it

Start the server in the background from any directory:

```
node <skill-dir>/scripts/swarm-console.mjs [--port 4186] [--runs <run-log-dir>]
```

`--runs` defaults to `~/.claude/skill-workbench/swarm/runs`. Port 4186 works in every browser; Safari refuses some higher ports, so pick a replacement from Safari's allowed range when 4186 is taken.

**Done when** `http://localhost:<port>/sessions` answers with a JSON list.

## 2. Hand over the link

The session menu lists every session that spawned subagents, newest first, and opens the newest. Another session spawning subagents can outrank the swarm, so name the swarm's session with `&session=<id>` — the orchestrator's own session id.

- Live swarm: `http://localhost:<port>/?view=board`
- One lane: add `&lane=<agent-id>`
- One moment: add `&t=<epoch-ms>` — a paused page writes it into the URL, so a copied link reopens the same moment.

Open it in the user's browser and give them the link. The page lists its own keys under `?`.

**Done when** the user has the link and the page shows the swarm's lanes.

## 3. Stop it

Stop the server by its background task id or PID when the user is finished, never by a process-name pattern — that kills other sessions' servers.

## Data contract

The console infers everything from habits the swarm skill already has. Each habit below is load-bearing; a swarm that drops one loses the matching part of the page.

| The swarm does | The console shows |
|---|---|
| Launches each lane as a depth-1 `Agent` whose description starts `Lane` and names its issues (`Lane C: #422→#423→#424`) | A board row and its queue. Without issue numbers, the queue falls back to the `-<issue>` suffix of branches the lane creates with `git worktree add -b`. |
| Gives each lane a `name` and resumes it with `SendMessage` to that name | Resumes on the lane zoom and graph edges; a resume clears the lane's notice |
| Ends each lane turn with `SubagentHandback`, first line saying what it needs — `READY TO MERGE …`, or an escalation naming `blocked`, `held` or `re-spec` | The **Needs you** bay and the tag on the lane's card |
| Runs every `gh pr merge` from the orchestrator session, on branches ending `-<issue>` | Issues moving to Merged, merge diamonds, PR links |
| Keeps the goal in a `TaskCreate` task and rewrites it with `TaskUpdate` (`MERGED: … RUNNING: … Next: …`) | The Goal panel, replayed as it stood at each moment. A run log's `- [ ]` Tasks lines stand in when there is no task. |

Stage is inferred from each lane's tool calls: edits and gate commands are **Build**, reviewer subagents and the lane's own server look are **Review**, `gh pr create` / `gh pr checks` / `git push` are **PR / CI**. A hand-back keeps the stage it interrupted.

**Notices** sit across stages. A lane handed back with no resume since raises one, ranked: escalation, then silence over 10 minutes, then ready to merge, then waiting on the orchestrator. It clears on a resume, a merge, or the lane moving again.
