# Roadmap

Durable direction and themes that are NOT yet scoped to a brief or milestone. Items here are capture-and-defer — they graduate to `docs/briefs/<name>.md` once grilled.

Per [`docs/agents/issue-tracker.md`](agents/issue-tracker.md), roadmap is the top of the three-level hierarchy: Roadmap → Brief → Issue.

---

## code-explorer agent (global default, repo-local override)

**Status:** sketch, not yet grilled. Out of current `Scope (locked)` in [`CONTEXT.md`](../CONTEXT.md) — this repo currently ships 7 Skills and no Agents. Agents would need a scope-expansion decision before this graduates.

**Premise.** Read-only code exploration is generic across repos. A global `~/.claude/agents/code-explorer.md` running on Sonnet handles "where is X defined", "find callers of Y", "grep for symbol K" for ~80% of repos at a fraction of Opus cost. Repo-local overrides handle the 20% where conventions, domain glossary, or hot-file deny rules matter.

**Why global first.** The built-in `Explore` agent (Anthropic-shipped) inherits the parent model — so on an Opus session it runs Opus. A custom global `code-explorer` pinned to Sonnet captures the cost win without sacrificing the read-only discipline.

**Sketch of the global agent shape:**

- Frontmatter: `model: sonnet`, `tools: Bash, Read, Grep, Glob` (no Edit/Write/Agent).
- Output discipline: `path:line — <snippet>` lines, cap at 20 matches + total count, no preamble, "no matches" + 2-3 alternative search terms tried on miss.
- Search bounds: skip `node_modules`, `.cache`, `dist`, `.git`, `__pycache__`, `build`, `.next`; respect `.gitignore`; never scan `~`.
- Hard scope: if the question is open-ended ("why does X work this way"), return "out of scope — use Plan agent" and stop. Read-only is enforced by the tool list AND by the prompt.

**When to fork to a repo-local agent.** Three tests; any yes ⇒ fork:

| Test | Example |
|---|---|
| Has paths or conventions a global agent will not know | snapshots live in `data/snapshots/YYYY-MM-DD/` |
| Has domain glossary worth grep-variant expansion | terms like `factor`, `alpha`, `decay` where global misses inflections |
| Needs project-local tools | repo ships a custom `bin/find-symbol` wrapper |

A repo-local agent is typically 20 lines extending global with deny-paths and known-hot-files. Lives at `<repo>/.claude/agents/<repo>-explorer.md`.

**Layered pattern.**

1. Global `code-explorer` (Sonnet) — covers most repos.
2. Repo-local agent only when global underperforms (hot files re-read, wrong dirs scanned, domain terms missed).
3. Project `CLAUDE.md` "do not read X" deny rules — cheaper than a new agent for simple cases.

Start global. Add repo-specific only when a session shows wandering in that repo's codeburn report.

**Open questions to grill before this graduates:**

- Does this repo (`stonematt-skills`) become a home for Agents alongside Skills? Or does the global `code-explorer` live in private dotfiles?
- If Agents land here, does `plugin.json` need a schema extension? Per handoff: "Hooks/agents/commands integration into the plugin.json — schema doesn't formally support; defer."
- Is there value in a public/private split for agents, analogous to the current split between public skills and private dotfiles?
- Should this be one repo-and-pattern or a separate `stonematt-agents` repo?
