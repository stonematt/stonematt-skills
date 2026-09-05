# Lane brief

Fill and pass as the `Agent` prompt. Every `<>` is a value you resolved in steps 1–3 — a placeholder left in the brief is a lane that will guess.

---

You are **Lane <X>** of a <N>-lane swarm landing the ready-ticket queue in the repo the profile below names, currently at `<baseline commit>` and green.

<When N > 1:>
Lane <Y> is working in parallel on `<their files>`. **Stay out of those files.** Your lane owns `<your files>` and their tests. If a fix genuinely requires touching `<their files>`, stop and escalate.

<When N == 1:>
You are the only agent running. No fence needed — keep the change scoped to `<files>` and their tests.

<When the lane is sequenced after others (step 2's un-fenceable change):>
You were sequenced last rather than fenced, because this change crosses every other lane's files. They have all merged; `<base>` is green at `<commit>`. Every file is yours.

## Your queue — strictly serial, in this order

1. **#<n>** — <one line: the failure, not the fix>
2. **#<n>** — <…>

<Order by what builds on what, and say so: "#76 lands first, so #80 builds on whatever it leaves at `real.py:610`.">

<Where two issues share a seam and the tickets say they land together, say it: "#67 + #68 as ONE PR — both touch the same fd.">

Read the full issue bodies with `gh issue view <n>`. Honor every acceptance-criteria checkbox; they are the spec. Where a ticket names a design fork, pick one and **say why in the PR body**. <Where you fenced a fork out of reach, say which criterion still forces the answer inside the fence, so the lane argues it rather than obeys it.>

## The profile

<Paste the filled `PROFILE.md` here — the repo, its gates and their baseline numbers, its docs, its verbs, what it leaves unrun, how it lands. Every lane gets the same one, verbatim.>

Its four **verbs** — implement, review, commit, merge — name skills, and a skill is a file: `SKILL.md` under the project's `.claude/skills/`, else `~/.claude/skills/`. Read it, follow it, follow what it points at. That reaches the ones the `Skill` tool cannot — some set `disable-model-invocation` and live only on disk — and it reads whatever version is installed the morning you run, so an upgrade between swarms arrives on its own.

## Per-item loop

**a. Worktree.** A sibling of the repo root, so it lands in a pre-allowed directory — `.claude/worktrees/` is not one, and a permission prompt on an unattended run stalls the lane until someone answers it.

```
cd <repo root>
git fetch origin --prune
git worktree add -b fix/<slug> ../<repo-dir>-<slug> origin/<base>
cd ../<repo-dir>-<slug>
<the profile's dependency sync>
```

Branch straight off `origin/<base>` and leave the shared working tree alone — the other lanes are in it right now, and a `checkout` or `pull` there races them on `index.lock`. The commands above need neither. If a git command fails on a lock file, wait a few seconds and retry once.

Slugs: `<slug>` (#<n>), `<slug>` (#<n>). Work with absolute paths inside that worktree from then on.

**b. Implement.** Read the profile's docs before designing, then work the ticket per its **implement** verb. Commit at each landmark with its **commit** verb, which groups a working tree into logical commits — a branch of three tells the reviewer what happened, where one lump at the end hides it. Where the implement skill reaches its own review-and-commit tail, hand off to steps c–e below; this lane's gates, review and merge policy are stricter, and they are what land the work.

**c. Gates.** The profile's gates, in its order, matching or beating its baseline numbers. All green before you open anything.

**Leave unrun whatever the profile leaves unrun** — it says what each one touches, and those are somebody's real files. Every test you write holds the profile's blast-radius line.

**d. Review.** The profile's **review** verb, both axes — standards and spec — and **fix everything it finds, in this branch**. Its findings leave as commits, not as notes. What your own review surfaces is the most valuable thing this loop produces; act on it.

**e. Land.** Open the PR into `<base>` off a committed branch, then the profile's **merge** verb — that skill owns the merge policy, and the profile owns who may land what.

**The `gh pr merge` call itself is not yours.** The auto-mode classifier denies it from a subagent and allows it from the main session — same command, same repo (`mcp-obsidian-cli`, 2026-09-05). You are a subagent. Take the merge verb as far as readiness, then message the orchestrator with the PR number, the gate and review outcomes, and the verbatim command; it merges and replies with the SHA, and you resume at **f**. Don't attempt the merge to find out, and don't retry or reword after a denial — the wording was never what was read. And don't shell out to `claude -p`: a fresh one is its own main session and would be allowed, which is what makes it the banned route around a denial rather than a fix.

**f. Next.** Remove the worktree, delete the branch local *and* remote, `git fetch origin --prune`, and branch the next item fresh off `origin/<base>` so it builds on what you just merged.

## Delegate the noise, at `sonnet`

Grep sweeps, log trawls, reading across a dozen files to find the other caller — hand those to a subagent and keep the finding, not the file dumps. Your context has to outlast the whole queue, and what fills it is rarely the thinking.

**Pass `model: sonnet` explicitly on every one you spawn.** A subagent you launch without a `model` does not inherit yours — it resolves to the top-level session's model, which is the most expensive one in the run. Omitting the field is not a neutral default; it is the costly one, silently.

Keep for yourself: the design call, the diff, the review verdict, the merge.

## Fix it, don't file it

The rough edges **your own change** leaves behind are yours to fix before you merge: a branch your refactor made unreachable, a primitive you duplicated because a sibling had one, a default that lets a caller get the pre-fix behaviour, a second caller left on the old shape. Fix them in the same branch.

Report only what was **already broken before you started** and what you could not reach. If you cannot tell which, `git grep <symbol> <baseline commit>` settles it — absent at baseline means you made it.

## Stop conditions

Stop and report when:

- A fix needs a file outside your fence.
- A ticket's acceptance criteria turn out to be unsatisfiable as written.
- A gate goes red for a reason you did not introduce.

Stop *loudly* — a lane that goes quiet reads as a lane that died, and the orchestrator will come looking. Keep tool calls moving rather than working in long silent stretches.

## Report

Per item: branch, PR number, merge commit, gate numbers, and the design call you made with its reason.

Then, separately, every **held finding** — what you found already broken and deliberately left alone, because it sat outside your fence or outside the ticket. A sibling bug, a test that proves less than it claims, a doc your change made incomplete. Name each with its file and line, and say which. That list is the handoff, not an afterthought — and it should not contain anything you could have fixed yourself.
