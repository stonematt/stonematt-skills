---
name: swarm-console
description: "Watch a swarm in flight, or replay a finished one, in a local browser console: lanes by stage, what needs you, a heartbeat per agent. Use when the user wants to see swarm progress, or when the swarm skill has launched its lanes."
---

The console reads what a swarm already writes — session transcripts, subagent metadata, the run log, the repo's PRs — and serves one page over it. It writes nothing. A swarm in flight shows live; any past session replays on a time scrubber.

## 1. Serve it

Run this in the background from the swarm's repo, or pass `--project <repo-path>`:

```
node <skill-dir>/scripts/swarm-console.mjs [--project <repo-path>] [--port 4186] [--runs <run-log-dir>]
```

One console serves every project on the machine. If one already runs, the script prints this project's link, says `reused`, and exits. Otherwise it starts on 4186, or on the next free port that isn't 4190, which Safari refuses, and says `started` with its pid. `--runs` defaults to `~/.claude/skill-workbench/swarm/runs`.

**Done when** the script has printed a link.

## 2. Hand over the link

Use the printed link: `http://localhost:<port>/?view=board&project=<slug>`. `project` scopes the tab to the repo's sessions, its worktrees included, and opens the newest. Two swarms in two repos are two tabs on one console. When the swarm's repo has another session spawning subagents, pin the swarm with `&session=<id>`, the orchestrator's own session id.

- One lane: add `&lane=<agent-id>`
- One moment: add `&t=<epoch-ms>`. A paused page writes it into the URL, so a copied link reopens the same moment.

Open it in the user's browser and give them the link. The page lists its own keys under `?`.

**Done when** the user has the link and the page shows the swarm's lanes.

## 3. Stop it

Stop the console only if this session started it. A `reused` console belongs to whoever started it, and other projects' tabs depend on it. Stop by the background task id or the printed pid, never by a process-name pattern.

## Data contract

The console infers everything from habits the swarm skill already has. Each habit below is load-bearing; a swarm that drops one loses the matching part of the page.

| The swarm does | The console shows |
|---|---|
| Launches each lane as a depth-1 `Agent` whose description starts `Lane` and names its issues (`Lane C: #422→#423→#424`) | A board row and its queue. Without issue numbers, the queue falls back to the `-<issue>` suffix of branches the lane creates with `git worktree add -b`. |
| Gives each lane a `name` and resumes it with `SendMessage` to that name | Resumes on the lane zoom and graph edges; a resume clears the lane's notice |
| Opens every lane hand-back with the lane brief's status line — `swarm: ready-to-merge issue=<n> pr=<n> head=<sha>`, `swarm: escalation issue=<n> reason=<…>`, `swarm: queue-done` | The **Needs you** bay and the tag on the lane's card, read exactly. Sessions from before the status line fall back to keywords (`ready to merge`, `blocked`, `held`, `re-spec`). |
| Runs every `gh pr merge` from the orchestrator session, on branches ending `-<issue>` | Issues moving to Merged, merge diamonds, PR links |
| Keeps the goal in a `TaskCreate` task and rewrites it with `TaskUpdate` (`MERGED: … RUNNING: … Next: …`) | The Goal panel, replayed as it stood at each moment. A run log's `- [ ]` Tasks lines stand in when there is no task. |

Stage is inferred from each lane's tool calls: edits and gate commands are **Build**, reviewer subagents and the lane's own server look are **Review**, `gh pr create` / `gh pr checks` / `git push` are **PR / CI**. A hand-back keeps the stage it interrupted.

**Notices** sit across stages. A lane handed back with no resume since raises one, ranked: escalation, then silence over 10 minutes, then ready to merge, then waiting on the orchestrator. It clears on a resume, a merge, or the lane moving again.
