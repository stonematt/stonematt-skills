# product-lead setup

Run once per product repo, in the repo's session, with Matt there. Each step writes one file; Matt approves each before it lands. Do the work on a feature branch off the integration branch and land it as one PR, `docs(product-lead): set up product lead`.

## 1. Read the repo first

Read `CLAUDE.md` / `AGENTS.md`, `README.md`, `GLOSSARY.md` or `CONTEXT.md`, `PRODUCT.md` and `DESIGN.md` if present, `docs/adr/`, and the open issues and milestones. Find the integration and release branches with `git branch -r`.

**Done when** you can say in two lines what the product is for and who uses it, and you have the branch names.

## 2. The product brief

Copy [`templates/brief.md`](templates/brief.md) to `docs/product-lead/brief.md` and fill it with Matt in one exchange per section:

- **Goals**: two to four strategic outcomes, in his words: where the product is headed and what it must become to get there, not the features it has. Read the live map's destination and the README's purpose, then ask Matt what comes after them. Point at `PRODUCT.md` or the README for the users rather than restating them.
- **Initiatives**: one line each, with its containers (map issue, spec, milestone). Draft the list from the open issues and maps, and let Matt cut and rename it.
- **Where the tickets live**: tracker, labels, milestone convention.
- **Drift**: the last `improve-codebase-architecture` review's commit, if Matt knows one. Otherwise record the integration branch's current HEAD as the baseline. *(Default: no known review means drift counts from setup.)* Thresholds start at 30 files or 1,500 lines.
- **Vault page**: the vault and the path for the status page. Propose `2a/<area>/<project>-status.md` under the project's area and confirm the area folder with Matt. *(Default: the design left the location open.)*

**Done when** every section is filled and Matt has said yes to the initiative list.

## 3. The panel: strategic and tactical

The panel has two halves, and setup drafts both. The **strategic panel** asks whether this is the right thing, headed the right way: the market, the story the product tells, its design language, and the people it serves. The **tactical panel** asks whether it works: for the user in the moment, for the code a year from now, and against the ways it can fail. A panel of only tactical seats checks that the product works but never checks where it is going. Two onboardings drafted only tactical seats, and Matt rejected both as too low level.

Draft every persona with Matt at `docs/panel/<name>.md`, and mark its half in its **Panel** line. Give each a concrete lens ("the cyclist checking results on a phone at the finish line"), not a role title.

1. **Strategic, from the library.** Start from [`personas/`](personas/): the FT data journalist, the brand referee and the marketer. Copy the ones that fit, and fill each one's **What I care about here** for this project. A product with no charts drops the FT seat. Copy `personas/ft-data-storytelling.md` alongside the FT seat.
2. **Strategic, for this project.** Add one or two seats for the people the product is about, when they differ from its users, such as the community it serves or the people its data describes. These lenses are domain experts (a youth development coach, a clinician, a teacher), not users. Many have no review skill; they read the served page and say so in their **Reviews with** line.
3. **Tactical.** Draft two or three: an end user on the device they really use, a maintainer who reads the code in a year, and the way the product most often fails here (a skeptic of its numbers, the next customer who must not see another's data).

Each persona names the skills it reviews with. Prefer `impeccable`, `ux-designer-skill`, `web-design-guidelines`, `code-review`, `security-review`, `improve-codebase-architecture`, `codebase-design`, `dataviz` and `stone-ai-sniff-test`; any other installed skill that fits the lens is fine. Check each named skill is installed (`ls ~/.claude/skills/`); one that isn't stays out of the file.

Leave the infra, deploy and cost seat empty; `security-review` stands in (SKILL.md step 5).

**Done when** both halves exist (at least two strategic and two tactical persona files), each with a lens, its panel, its skills, what it cares about here and an empty verdict log, and Matt has approved each lens.

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
