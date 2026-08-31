# Swarm profile

What one repo answers once, in one place. Fill it at step 3; paste it whole into every lane brief.

Leave the filled copy at `.claude/swarm-profile.md` in the repo. The next swarm reads it instead of re-deriving it — and reading a line you wrote eight months ago is where a stale one shows up. Re-run the gates and the probe every time; those two rows are the run's, not the repo's.

---

**Repo** `<owner/repo>` · root `<abs path>` · base branch `<base>`

**Ready label** `<the label that narrows the issue list — or: none, so every open issue takes the finish-alone test>`

**Read before designing** `<AGENTS.md, CONTEXT.md, docs/adr/ — whatever this repo keeps>`

**Dependency sync** `<the command that makes a fresh worktree runnable — e.g. uv sync>`

**Gates**, in this order, all green before anything opens:

| gate | command | baseline at `<commit>` |
| --- | --- | --- |
| `<tests>` | `<uv run pytest>` | `<561 passed, 26 deselected>` |
| `<types>` | `<uv run mypy>` | `<Success, 22 source files>` |

**Blast radius** — probes planted at `<the temp root, the home config dir, any live data dir>`, gate set run at `<commit>`: `<which markers died, which survived>`. A lane's own new tests hold that line: `<what a new test pins, and to what>`.

**Leave unrun** `<script path>` — `<what it touches, and whose files those are>`.

**Verbs** — implement `<implement>` · review `<code-review>` · commit `<stone-commit>` · merge `<stone-merge>`

**Landing policy** `<who may self-merge and into what; branches that need a human; attribution rules>`
