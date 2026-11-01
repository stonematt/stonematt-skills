# swarm-board

A Claude Code mod (a plugin with a hooks module, not a skill) that keeps a
[`swarm`](../swarm/SKILL.md) in view while you work in any session of the same
repo. It draws one row per active swarm above the prompt:

```
Release-blocking fixes from the goal PR review (spec #66) · 4/5 done · 1 running · D stalled 12m
```

Each row shows the swarm's goal, lanes done out of lanes, how many lanes are
running, then a flag for each lane that needs attention: **needs you** (red) for
an escalation, **stalled** (yellow) for a running lane silent over 10 minutes.
The goal is cut first, so the counts and flags always fit. The band is gone when
no swarm is active. `/swarm-board` opens a pane with the same one line per
swarm; Escape or `/swarm-board close` closes it. `/swarm-board reload` rescans
now instead of waiting for the next 20-second poll. All three run mid-turn.

For the full picture (stages, the graph, replay), use
[`swarm-console`](../swarm-console/SKILL.md).

## What it reads

It reads files only, every 20 seconds, and writes nothing:

- `~/.claude/projects/<repo>/<session>/subagents/*.meta.json`: each lane link's
  description, `Lane <X>: #<n> (<k>/<total>) <objective>`, and its `finished` flag.
  A swarm is any session of the repo, or of its `.claude/worktrees/`, with such links.
- The last 64 KB of a finished lane's transcript, for its `swarm:` status line.
- The run log in `~/.claude/skill-workbench/swarm/runs/` whose `Session:` line
  names the session: its `# ` title is the goal. Without one, the session's own
  title, then its ticket numbers.

These are the habits [`swarm-console/CONTRACT.md`](../swarm-console/CONTRACT.md)
records. A change to them in the `swarm` skill reaches this mod too.

A swarm drops off the band 30 minutes after its last lane activity.

## Install

Linked like the other in-progress skills, from the main checkout:

```
ln -s ~/src/github.com/stonematt/stonematt-skills/skills/in-progress/swarm-board ~/.claude/skills/swarm-board
```

Claude Code loads a plugin folder found in `~/.claude/skills/` by itself and
reloads it when its files change. A session started before the link was made
picks it up at its next start.

`scripts/link-skills.sh` removes links into the repo that are not shipped skills,
this one included, as it does the `swarm` and `swarm-console` links. Run the
`ln` again after it.

## Develop

```
claude plugin validate skills/in-progress/swarm-board
claude plugin test skills/in-progress/swarm-board
```

`tsc -p skills/in-progress/swarm-board` type-checks it once a session has loaded
the mod, which writes the API types into `.claude-plugin/types/` (ignored).
