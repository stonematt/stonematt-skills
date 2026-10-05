# skills/in-progress

Drafts not yet ready to ship. Excluded from `plugin.json` and `link-skills.sh`.

| Skill | What it does |
|---|---|
| `stone-adopt-pocock` | Adopt the Pocock skill suite into a repo — preflight, role binding, workbench. |
| `bse-monitor` | Watch a repo for ready BSEs and land each through a fresh subagent. User-invoked only. |
| `swarm` | Land a whole issue queue unattended: file-fenced lanes of agents in parallel, each lane running the repo's `implement` verb serially. |
| `swarm-console` | Watch a swarm in flight, or replay a finished one, in a local browser console: lanes by stage, what needs you, a heartbeat per agent. |

The `stone-` prefix is a convention for names likely to collide, not a rule
([ADR-0004](../../docs/adr/0004-namespace-is-a-convention.md)). Distinctive names like `swarm`
can be promoted bare.
