# Lane brief

Fill and pass as the `Agent` prompt. Every `<>` is a value you resolved in steps 1–3 — a placeholder left in the brief is a lane that will guess.

---

You are **link <k> of <total> in Lane <X>** of a <N>-lane swarm landing the ready-ticket queue in the repo the profile below names, currently at `<baseline commit>` and green.

<When k > 1:>
This lane's earlier links have merged: <#n → what it left: the module, helper or component, and where>. Build on what they left; do not rebuild it.

<When N > 1:>
Lane <Y> is working in parallel on `<their files>`. **Stay out of those files.** Your lane owns `<your files>` and their tests. If a fix genuinely requires touching `<their files>`, stop and escalate.

<When N == 1:>
You are the only agent running. No fence needed — keep the change scoped to `<files>` and their tests.

<When the lane is sequenced after others (step 2's un-fenceable change):>
You were sequenced last rather than fenced, because this change crosses every other lane's files. They have all merged; `<base>` is green at `<commit>`. Every file is yours.

## Your queue — strictly serial, in this order

<Usually one ticket: the lane's next. Two only when they land as one PR.>

1. **#<n>** — <one line: the failure, not the fix>
2. **#<n>** — <…>

<Order by what builds on what, and say so: "#76 lands first, so #80 builds on whatever it leaves at `real.py:610`.">

<Where two issues share a seam and the tickets say they land together, say it: "#67 + #68 as ONE PR — both touch the same fd.">

Read the full issue bodies with `gh issue view <n>`. Honor every acceptance-criteria checkbox; they are the spec. Where a ticket names a design fork, pick one and **say why in the PR body**. <Where you fenced a fork out of reach, say which criterion still forces the answer inside the fence, so the lane argues it rather than obeys it.>

## The profile

<Paste the filled `PROFILE.md` here — the repo, its gates and their baseline numbers, its docs, its verbs, what it leaves unrun, how it lands. Every lane gets the same one, verbatim.>

Its four **verbs** — implement, review, commit, merge — name skills, and a skill is a file: `SKILL.md` under the project's `.claude/skills/`, else `~/.claude/skills/`. Read it, follow it, follow what it points at. That reaches the ones the `Skill` tool cannot — some set `disable-model-invocation` and live only on disk — and it reads whatever version is installed the morning you run, so an upgrade between swarms arrives on its own.

## Per-item loop

**a. Worktree.** Pick the variant the orchestrator launched you for.

<When the lane was launched with `isolation: "worktree"`:>
You are already isolated. Branch in place, and do the same between items:

```
git fetch origin --prune
git checkout -b fix/<slug> origin/<base>
<the profile's dependency sync>
```

<Otherwise:>
A sibling of the repo root, so it lands in a pre-allowed directory — `.claude/worktrees/` is not one, and a permission prompt on an unattended run stalls the lane until someone answers it.

```
cd <repo root>
git fetch origin --prune
git worktree add -b fix/<slug> ../<repo-dir>-<slug> origin/<base>
cd ../<repo-dir>-<slug>
<the profile's dependency sync>
```

Branch straight off `origin/<base>` and leave the shared working tree alone — the other lanes are in it right now, and a `checkout` or `pull` there races them on `index.lock`. The commands above need neither. If a git command fails on a lock file, wait a few seconds and retry once.

Slugs: `<slug>` (#<n>), `<slug>` (#<n>). Work with absolute paths inside that worktree from then on.

Run every git and gh call as one plain command — no variables, loops, pipes or heredocs on the same line — and pass PR and issue bodies with `--body-file`. A worktree guard refuses the compound forms, and each refusal costs a repair loop.

**b. Implement.** Read the profile's docs before designing, then work the ticket per its **implement** verb. Commit at each landmark with its **commit** verb, which groups a working tree into logical commits — a branch of three tells the reviewer what happened, where one lump at the end hides it. Where the implement skill reaches its own review-and-commit tail, hand off to steps c–f below; this lane's gates, critique, review and merge policy are stricter, and they are what land the work.

**c. Gates.** The profile's gates, in its order, matching or beating its baseline numbers. All green before you open anything.

Run every gate in the **foreground**, with a reporter that streams, and read its exit code. A pipe hands back the last command's exit code, so `| tail` turns a red gate green. A turn parked on a silent background job trips the stream watchdog and stalls the lane.

**Leave unrun whatever the profile leaves unrun** — it says what each one touches, and those are somebody's real files. Every test you write holds the profile's blast-radius line.

**d. Look.** <For a ticket that changes UI; otherwise skip to e.> Serve this branch on your **own server**, with the profile's command, and run the profile's visual critique skill against it at desktop and phone width. <Browser: take turns with the session's shared browser tool, or use your own headless one — say which.> Fix what holds up inside your fence and ticket, re-run the gates, then stop the server before review. The critique summary goes in your hand-back. Where the ticket asks for screenshots, save them outside the repo and list their paths; `gh` cannot attach images, so attaching them is the owner's known step.

**e. Review.** The profile's **review** verb, both axes — standards and spec. Every reviewer subagent you brief is **read-only**: it reads the diff and the files at your branch head, and it never checks out, commits, stashes or writes a file — the worktree, its HEAD and its commits stay yours. Fix every finding that sits inside your fence and your ticket, in this branch; its findings leave as commits, not as notes. A finding outside either is a held finding for your report.

**f. Land.** Open the PR into `<base>` off a committed branch, then the profile's **merge** verb — that skill owns the merge policy, and the profile owns who may land what. Watch CI with `gh pr checks --watch` in the foreground; it can exit early on a network reset, so re-run it until every check reports pass or fail. An early exit is not a result. If any commit lands after review — a CI fix — review that delta before you hand back, and say so.

Take it as far as readiness, then end your turn with the `ready-to-merge` status line, the PR number, the gate, critique and review outcomes, the head SHA pasted from `git rev-parse HEAD` output in this turn (never recalled), and the verbatim `gh pr merge` command. The orchestrator runs the merge and resumes you with the SHA; you pick up at **g**. If any command is denied, end your turn with an `escalation` status line (`reason=denied`) and that command verbatim, and let the orchestrator decide.

**g. Next.** In a sibling worktree: remove it, delete the branch local *and* remote, `git fetch origin --prune`, and branch the next item fresh off `origin/<base>`. Isolated: delete the branch remote, `git fetch origin --prune`, and `git checkout -b` the next item off `origin/<base>`. Either way the next item builds on what you just merged.

## Delegate the noise, at `sonnet`

Grep sweeps, log trawls, reading across a dozen files to find the other caller — hand those to a subagent and keep the finding, not the file dumps. Your context has to outlast the whole queue, and what fills it is rarely the thinking. Delegate a read that is large and independent of your next edit; do a one-file lookup yourself. Verification is the review verb's job and the orchestrator's — the review verb is the only reviewer you launch.

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

Stop by ending your turn with an `escalation` status line, then the report below, the stop reason first. The orchestrator reads only what your final turn says.

## Status line

The **first line** of every turn you end — whether you end it with `SubagentHandback` or in plain text — is a status line, plain text with nothing before it. The orchestrator and the swarm console read it exactly; the rest of the turn is for people.

```
swarm: ready-to-merge issue=<n> pr=<n> head=<sha>
swarm: escalation issue=<n> reason=<fence | unsatisfiable | red-gate | denied>
swarm: queue-done
```

`ready-to-merge` ends step **f**. `escalation` ends every stop and every denied command. `queue-done` ends your last item, after its step **g**.

## Report

End with this block, one entry per item, then your prose:

```yaml
lane: <X>
items:
  - issue: <n>
    branch: fix/<slug>
    pr: <n>
    head_sha: <pasted from git rev-parse HEAD>
    merge_sha: <sha or pending>
    critique: <one line, or n/a when no UI changed>
    gates: <numbers, e.g. "tests 612 passed; types ok">
    review_findings: {fixed: <n>, held: <n>}
    design_call: <one line, with its reason>
left: <what the next link can build on: new modules, helpers, components, with paths; or none>
incidents:   # anything that cost a repair loop or a human: denial, permission prompt, lock retry, fence pressure
  - <kind>: <one line, verbatim command where there was one>
stop_reason: <queue-done | fence | unsatisfiable | red-gate | denied>   # the status line's values
```

Then, separately, every **held finding** — what you found already broken and deliberately left alone, because it sat outside your fence or outside the ticket. A sibling bug, a test that proves less than it claims, a doc your change made incomplete. Name each with its file and line, and say which. That list is the handoff, not an afterthought — and it should not contain anything you could have fixed yourself.
