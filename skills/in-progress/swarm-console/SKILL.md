---
name: swarm-console
description: "Open, stop, or replay the swarm console — a local browser view of a swarm's lanes. Use when the user wants to see swarm progress or a past run, or when the swarm skill has launched its lanes."
---

The console reads what a swarm already writes — session transcripts, subagent metadata, the run log, the repo's PRs — and serves one page over it for one repo. It writes nothing. A swarm in flight shows live; any past session of the repo replays on a time scrubber.

## 1. Start it, or find it

From the swarm's repo — any worktree of it — start the installed copy of the script, detached:

```
nohup node ~/.claude/skills/swarm-console/scripts/swarm-console.mjs [--project <repo-path>] [--runs <run-log-dir>] > <scratchpad>/swarm-console.log 2>&1 & disown
```

Then read the log's first line. Detached is what keeps the console alive past your turn; a tool's own background mode ends the server when the turn ends. The installed copy is what keeps it alive past a merge; the server re-reads its page on every load, so a copy inside a worktree breaks when that worktree is removed.

The script is the record of what runs; nothing about the console belongs in memory. The log holds one of:

- `started (pid <pid>) … → <link>` — this session owns that console.
- `reused (pid <pid>) … → <link>` — the repo's console was already up; the script exits.

Each repo gets its own console on its own port, starting at 4186. `--runs` points at the swarm skill's run logs when they live somewhere other than its default.

**Done when** the log shows a link.

## 2. Open it

Open the link in the browser the user named — on macOS `open -a "Google Chrome" <link>`, or plain `open <link>` for their default — and give them the link. It opens the repo's newest session with subagents; pin a different one with `&session=<id>`, the orchestrator's own session id. `&lane=<agent-id>` zooms to one lane; `&t=<epoch-ms>` reopens a moment, and a paused page writes it into its URL. The page lists its keys under `?`.

**Done when** the user has the link and `curl -s -o /dev/null -w '%{http_code}' <link>` answers `200`.

## 3. Stop it

```
node ~/.claude/skills/swarm-console/scripts/swarm-console.mjs --stop [--project <repo-path>]
```

It finds the repo's console by asking each port who it is, and stops that one. Stop a console this session started, or one the user asks you to stop.

**Done when** the script prints `stopped` or `no swarm console running`.

## Lessons

Notes for the next edit of this skill live in `~/.claude/skill-workbench/swarm-console/`, outside any repo. When the console misleads, breaks, or the user asks for a change you did not make, append a dated entry to `feedback.md` there: what happened, the session it came from, and the line of this skill or its scripts you would change. Read that file, and [`CONTRACT.md`](CONTRACT.md) for what the page reads from the swarm, before editing the skill or its scripts. An entry stays open until its fix lands; then mark its heading `(folded <commit>)`.
