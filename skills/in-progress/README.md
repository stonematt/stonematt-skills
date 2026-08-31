# skills/in-progress

Drafts not yet ready to ship. Excluded from `plugin.json` and `link-skills.sh`.

| Skill | What it does |
|---|---|
| `stone-adopt-pocock` | Adopt the Pocock skill suite into a repo — preflight, role binding, workbench. |
| `swarm` | Land a whole issue queue unattended: file-fenced lanes of agents in parallel, each lane running the repo's `implement` verb serially. |
| `obsidian-quick-capture` | One-call capture into an Obsidian vault inbox from any project — no template, minimal frontmatter, first-mention wikilinks. |

Neither `swarm` nor `obsidian-quick-capture` is `stone-`-prefixed. Every shipped skill here is;
whether that prefix is a membership rule or a convention is unsettled, and `in-progress` is the
right place to leave the question open. Decide before promoting either.

`obsidian-quick-capture` is **proven and in daily use** — unlike the other two, it sits here for
the naming question and the publish decision, not because it is a draft. Promoting it to
`productivity/` is a one-directory move once both are settled. Before that move, note that its
vault name defaults to `tyee`; the `vault=` argument is documented, so this is a default rather
than a hardcoding, but a shipped skill should probably default to nothing and say so.
