# product-lead setup

Run once per product repo, in the repo's session, with Matt there. Each step writes one file; Matt approves each before it lands. Do the work on a feature branch off the integration branch and land it as one PR, `docs(product-lead): set up product lead`.

## 1. Read the repo first

Read `CLAUDE.md` / `AGENTS.md`, `README.md`, `GLOSSARY.md` or `CONTEXT.md`, `PRODUCT.md` and `DESIGN.md` if present, `docs/adr/`, and the open issues and milestones. Find the integration and release branches with `git branch -r`.

**Done when** you can say in two lines what the product is for and who uses it, and you have the branch names.

## 2. The product brief

Copy [`templates/brief.md`](templates/brief.md) to `docs/product-lead/brief.md` and fill it with Matt in one exchange per section:

- **Goals**: two or three outcomes, in his words. Point at `PRODUCT.md` or the README rather than restating them.
- **Initiatives**: one line each, with its containers (map issue, spec, milestone). Draft the list from the open issues and maps, and let Matt cut and rename it.
- **Where the tickets live**: tracker, labels, milestone convention.
- **Drift**: the last `improve-codebase-architecture` review's commit, if Matt knows one. Otherwise record the integration branch's current HEAD as the baseline. *(Default: no known review means drift counts from setup.)* Thresholds start at 30 files or 1,500 lines.
- **Vault page**: the vault and the path for the status page. Propose `2a/<area>/<project>-status.md` under the project's area and confirm the area folder with Matt. *(Default: the design left the location open.)*

**Done when** every section is filled and Matt has said yes to the initiative list.

## 3. The panel: three groups

Draft each persona from [`templates/persona.md`](templates/persona.md) with Matt, at `docs/panel/<name>.md`. Each belongs to one **group**, and the group decides when it sits (SKILL.md step 5):

- **Tactical**: the people who use the product and the ways it can fail. An end user on the device they really use, a maintainer who reads the code in a year, an operator who pays for it. Two or three seats.
- **Community**: the people the product is about or serves, when they differ from its users ("the parent of a junior rider whose name is in the results"). Draft it when the product has such a community.
- **Strategy**: market and craft experts for larger design and strategy efforts (a data journalist, a marketer, a brand keeper). Propose the seats; Matt may defer this group to the first strategy effort.

Give each a concrete lens ("the cyclist checking results on a phone at the finish line"), not a role title.

Each persona names the skills it reviews with: any installed skill that fits its lens (`code-review`, `security-review`, `impeccable`, `codebase-design`, `dataviz`, `stone-ai-sniff-test`, and the like). Check each named skill is installed (`ls ~/.claude/skills/`); one that isn't stays out of the file.

Leave the infra, deploy and cost seat empty; `security-review` stands in (SKILL.md step 5).

**Done when** two or three tactical persona files exist, the community and strategy groups are each drafted or deferred by Matt, every file has a group, a lens, its skills, what it cares about here, and an empty verdict log, and Matt has approved each lens.

## 4. The Graphify hook

The hook keeps the local knowledge graph fresh on merges to the integration branch: it runs `graphify update .` and flags doc changes for a full `/graphify`. It never commits.

1. Find the hooks dir: `git rev-parse --git-path hooks` (a worktree shares the main checkout's).
2. A `post-merge` already there → show Matt the diff against [`templates/post-merge`](templates/post-merge) and let him choose. Never overwrite it silently.
3. Otherwise copy [`templates/post-merge`](templates/post-merge) in and `chmod +x` it. It is a verbatim copy of `nitimini/.git/hooks/post-merge`. If the integration branch is not `dev`, change the one `[ "$branch" = "dev" ]` line.
4. No `graphify-out/graph.json` in the repo → the hook exits silently. Tell Matt a first `/graphify .` is needed for it to do anything.

Hooks are not tracked by git, so this step leaves nothing in the PR. Note it in the PR body.

**Done when** the hook is executable at the hooks path, or Matt kept his own, and he knows whether a first `/graphify` is needed.

## 5. The lessons file

Copy [`templates/lessons.md`](templates/lessons.md) to `docs/product-lead/lessons.md`.

**Done when** it exists with its header and no entries.

## 6. First run

Commit, push and open the setup PR. Then go back to SKILL.md step 1 and run a status check, so the first status page lands in the vault and Matt sees the rungs you inferred while he can still correct them.

**Done when** the setup PR is open and the first status page is written.
