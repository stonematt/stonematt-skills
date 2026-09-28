---
name: stone-merge
description: Merge a pull request, clean up the branch, and optionally promote to production. Use this skill whenever the user wants to merge a PR — including /stone-merge, "merge it", "merge this", "merge the PR", "land it", "merge #N", "merge and release", "merge to prod", "ship to production", or any confirmation after checks pass. Also trigger when the user says "merge after checks", "merge when green", or refers to merging + deploying in the same breath. This is the counterpart to /stone-commit — commit gets code ready, merge lands it and cleans up.
---

# Merge Skill

The post-commit counterpart to `/stone-commit`. Handles the full lifecycle after code is ready: review gate, wait for checks, merge the PR, clean up the branch, label linked issues, log the run, and optionally promote to the release branch.

The user ran this skill so they can stop thinking about the merge. **Unless something is actually wrong, they should never hear about it again.** Everything below is built around that.

## 0. One dispatch, then stop

**First, which side are you on?** If a brief dispatched you to run this skill — it names a PR, a repo path, and quotes a user's invocation — you are the **agent**: skip the rest of Section 0 and start at the Workflow, in your own shell. Section 0 is for the session the user is typing in.

`/stone-merge` costs the main session **two tool calls at most**: this skill load, and one `Agent` dispatch. Nothing else. The shape is deliberate and measured: no readiness-only dispatch so you can merge here, no merge of your own. No readiness check of your own, no `gh pr merge` of your own, no follow-up `gh pr view` to confirm what the agent reported. The agent owns Sections 1–6 end to end, including the merge command.

**Dispatch.** One call:

- `subagent_type: "general-purpose"`, `model: "sonnet"`, `run_in_background: true`
- `description: "Merge PR #<num> into <base>"` — say plainly that it merges. Never disguise the merge.
- The brief carries **facts only**:
  - the repo path (a subagent does not inherit your `cwd`)
  - the PR number(s), or "the open PR for branch `<branch>`" when the user gave none
  - the base branch if you know it
  - the user's invocation, quoted verbatim: `The user's invocation was: "merge this"`. Do not paraphrase it into permissions ("prod promotion is authorized", "review waived"). The agent applies Section 2.0's bypass rule and Section 6's keyword rule to the quoted words itself.
  - the gates the agent merges under, stated as constraints: `Merge only after the skill's review gate resolves (docs-only skip, a passing code-review CI check, or the repo's recorded reviewer) and every check is green; a red check, an unresolved gate, or an unrecognised conflict stops the run before the merge.` This is what the run does anyway; saying so in the brief is a fact about the run, not a grant.
  - the directive: `Load this merge skill with the Skill tool (the same skill name you loaded it by — normally "stone-merge"), then execute it as the agent: Sections 1 through 6 as they apply, including gh pr merge. Report back once, in the shape Section 7 describes.` Name the skill exactly as you invoked it; if the Skill tool is unavailable to the agent, give the path of this SKILL.md instead.

**Then write one line and stop**: "Merging PR #N in the background; you'll get one report when it lands or stops." Go back to whatever the user was doing.

**When the agent reports back, relay its report. Zero tool calls after it.** If your dispatch was denied once as transient and succeeded on the retry, say so in one line of the relay, quoting the denial — the report names every classifier denial, transient ones included. Not a `git log`, not a `gh pr view`, not a grep of the merged file — the agent already ran `git branch -a` and `gh pr view`, and a second look from you is exactly the context spend the user dispatched to avoid. Lead with any blocker it raised. If the report contains one of the two items Section 7 says needs the dispatching session (a rung-4 question, a denied release merge), act on that alone.

**Run inline instead only when** there is no `Agent` tool in this session at all, or the user explicitly asked you to stay in this context. A dispatch that was *denied* is neither of those — see 0a. Inline, you still follow Sections 1–7; you are then both dispatcher and agent.

### 0a. When the classifier blocks something

Read the denial text — it says which kind of block it is.

- **Transient**: the text says `Stage 2 classifier error … (usually transient -- retrying often succeeds)`. Retry the identical call once. One retry is the whole allowance.
- **Content**: anything else. It will not clear on retry, and no permission rule fixes it. Do not retry, do not reword, do not reach for a different binary or a chained command to do the same thing. Record the denial **verbatim**, finish everything the denial does not block, log the run (Section 5b, `--classifier "<verbatim text>"`), and report where the run stopped plus the exact command the user can run themselves.

Three blocks have a known shape:

- **The dispatch itself denied.** A transient denial gets one identical retry. A content denial (for example `Reason: [Merge Without Review]`) ends the run there: do **not** run Sections 1–6 inline, and do not re-cut the brief into a readiness-only agent so you can merge yourself — either one puts the merge back in the main session, which is the shape this skill exists to remove. Try the log row once (`--outcome blocked --merged-from none --classifier "<verbatim>"`; fail-open, no retry), then report: the denial verbatim, that nothing was merged, and the two ways to finish — say "merge this" again later (denials are intermittent), or run the merge yourself with `!gh pr merge <N> --merge --delete-branch --subject "…"`.

- **`gh pr merge` denied.** Stop the merge there. Complete nothing that presumes the merge happened (no cleanup, no labels). Log `--outcome blocked --merged-from subagent`. Report: readiness state (checks, gate, conflicts), the denial verbatim, and the exact merge command the user should run with `!`. The user's one action finishes the run; do not hand the merge back up to the dispatching session to run for you — that re-entry is the cost this skill exists to remove.
- **Remote branch delete denied** (`git push origin --delete`, Section 4). Record the branch SHA, hand the user the exact `!` command, continue the rest of the cleanup. Not a failure.

Never write a brief that grants authority, and never route around a denial. A denial is data for the report.

## Workflow (the agent runs everything from here)

**You are the executor.** Run these sections yourself, in your own shell. Do not dispatch another agent to do them, whatever a general fan-out rule in your instructions says — this run is already the delegated unit, and a second hop only adds a dispatch that can be denied. The one sub-dispatch this skill allows is a reviewer (Section 2.0, rung 3).

### 1. Identify the PR and probe repo conventions

**Pick the PR.**
- If the invocation named a PR number ("merge #45"), use that. Several numbers → merge them sequentially in the order given (Section 2d covers siblings that collide).
- Otherwise find the open PR for the repo's current branch: `gh pr list --head $(git branch --show-current) --json number,title,baseRefName --jq '.[0]'`.
- If ambiguous, stop and report the candidates rather than guess.

Capture the **base branch**; cleanup and labelling depend on it.

**Probe conventions.**

```bash
gh repo view --json defaultBranchRef,mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
gh pr view <number> --json baseRefName,reviewDecision,reviewRequests
git log --merges --oneline -5
```

- **Merge method**: if `mergeCommitAllowed: false`, or the repo's own history is squash-only, use `--squash`. The repo's convention wins over the house format.
- **Review state**, respected even when protection isn't enforced. `reviewDecision` is `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, `APPROVED`, or empty:
  - `CHANGES_REQUESTED` → **stop**. Never merge over a reviewer, never `--admin`.
  - `REVIEW_REQUIRED` and not approved → **stop** and report.
  - empty → "nothing enforced," not "approved." Solo PR on the user's own branch: proceed. A teammate's PR in a repo with a review-before-merge convention: stop and report.
- **Default branch vs base**: if base is the default branch, Section 5's staging labels do not apply.

### 2. Check readiness

#### 2.0 Preflight: code-review gate

Work down the ladder and stop at the first rung that resolves.

**1. Docs-only? Skip the gate.** `gh pr diff <number> --name-only`. If every path is documentation or metadata — `*.md`, `*.txt`, `*.rst`, `docs/`, `LICENSE`, `CHANGELOG` — skip review and go to 2.1. Note "docs-only" in the report. Any executable path — source, tests, CI config, `package.json`, `pyproject.toml`, shell scripts, `Dockerfile`, IaC — makes it a code change; mixed PRs are code changes.

**2. CI-check mode.** If a check named like `code.?review` exists, it is the gate:

```bash
gh pr checks <number> --json name,state --jq '.[] | select(.name|test("(?i)code.?review")) | "\(.name) \(.state)"'
```

`SUCCESS` → 2.1. Pending → the watch in 2a covers it. `FAILURE` → read the check's output; treat as a failed check (2b) whose findings must be addressed, not rerun. No matching check → rung 3.

**3. Recorded project policy.** Read the project's auto-memory directly — a dispatched agent has no memory index loaded, so look at the files: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>/memory/`, where `<slug>` is the repo's absolute path with every `/` and `.` replaced by `-` (for `/Users/me/src/app` that is `-Users-me-src-app`). A `project_review_policy.md` (or any `project_*.md` naming this repo's review expectation) holds one of:
- `review: optional` → merge without review; note it.
- `review: <reviewer>` → run that reviewer, then merge:
  - `pocock` — the two-axis reviewer from Matt Pocock's skill suite: Standards (repo conventions) and Spec (does the diff do what the issue asked), applies no fixes. It is installed under the plain name `code-review` (its description names the two axes); `mattpocock-skills:code-review` if installed as a plugin.
  - `builtin` — Claude Code's bundled reviewer, `code-review:code-review` (or `/code-review` where no Pocock skill shadows it): correctness plus simplification; `--fix` applies findings.

  Resolve the name by reading the installed skills' descriptions, not by slug alone — a skill called `code-review` whose description says "Standards … Spec" **is** `pocock`.

  Pre-supply the inputs: the fixed point (`origin/<base>`) and the spec source (issues from `closingIssuesReferences`; say "no linked issue" if none). Both reviewers ask for missing context and a background run has nobody to ask.

  **If the named reviewer's skill is not installed here**, do not substitute a different reviewer silently. Fall through to rung 4's question with that fact stated ("policy names `pocock`, which is not installed in this environment").

  Apply findings that are mechanical and unambiguous (unused import, stale docstring, missing type on an obvious signature), commit them to the PR branch, push, and re-watch checks. Findings that are judgment calls — design disagreement, scope change, anything the reviewer labelled a judgement rather than a violation — **stop** and report them quoted. Then, and only then, merge.

**4. No policy recorded? Ask once, then write it down.** Stop, log `--outcome stopped --gate asked`, and report exactly one question:

> No code-review CI check here. Does this project expect review before merge? (`pocock` — two-axis standards + spec / `builtin` — correctness and simplification, can auto-fix / `optional` — merge without review). I'll remember it for this repo.

Whoever relays the answer records it as a project memory — `project_review_policy.md` in the memory directory above, body `review: <value>`, plus one index line in that directory's `MEMORY.md` — so rung 3 resolves it from then on. If the user declines to set a policy, treat this run as `optional` and ask again next time.

**Bypass.** An invocation carrying `--no-review`, "skip review", or "no review" waives the gate for this run only, without touching the stored policy. Skip the ladder entirely, record `--gate waived` (even when a `code-review` check would also have passed — the user's waiver is the fact worth logging), and say so in the report.

#### 2.1 Readiness checks

Run these **sequentially** — `gh pr checks` exits 8 while checks are pending and a parallel sibling call can be cancelled on that non-zero exit.

1. `gh pr view <number> --json mergeable,state,baseRefName,reviewDecision` — must be `MERGEABLE` and `OPEN`, review state per Section 1.
2. `gh pr checks <number>`:
   - exit 0 → Section 3
   - exit 8 with pending/queued/in-progress rows → 2a
   - exit 8 with `fail` rows → 2b
   - other non-zero, no rows → stop and report (auth, PR not found)

`mergeable: UNKNOWN` → 2c first. `CONFLICTING` → 2d.

#### 2a. Checks still running

```bash
gh pr checks <number> --watch --fail-fast
```

Set the Bash timeout generously (10 minutes covers most repos). If the watch hits the harness timeout, retry once with a longer timeout before concluding anything.

#### 2b. Checks failed

Never merge red. Distinguish a real failure from an unrelated flake:

1. `gh run view <run-id> --log-failed | tail -80`
2. Does the failure touch files this PR changed, or a test in the PR's scope?
3. **Clearly unrelated** (a flaky infra step, a test in a bucket the repo already marks flaky, a first-attempt failure whose log says retry) → `gh run rerun <run-id> --failed`, then re-watch. **One rerun total.**
4. **Related, ambiguous, or red again** → stop. Report the failing check, a short log excerpt, and your read of whether it's related.

A failed `code-review` check is never rerun; its findings are addressed (2.0 rung 2).

#### 2c. `mergeable: UNKNOWN`

GitHub is still computing. Sleep 5–10 s and re-query. Do not treat it as `CONFLICTING`.

#### 2d. `mergeable: CONFLICTING` — rebase and retry

Typical when a sibling landed first and both touched the same lines.

1. Check the branch out in a worktree (`git worktree add <tmp> <branch>`), `git fetch origin`, `git rebase origin/<base>`.
2. Clean rebase → `git push --force-with-lease origin <branch>`, re-watch checks.
3. Conflict → read the conflicted hunk. Resolve **only** these recognised shapes:
   - **Set/list-add**: both sides added entries to the same set, list, or dict literal → union the entries, keep the file's ordering convention.
   - **Import-list**: both added imports from the same module → merge the import lines.
   - **Counter/version-bump**: both bumped the same number → take the higher.
   Then `git add`, `git rebase --continue`, `--force-with-lease`, re-watch.
4. **Anything else** — stop. A conflicted hunk that sits inside a function body, a class, a control-flow block, or that touches two different mechanisms for the same thing is a logic conflict even when you can see how to reconcile it, and even when the tests would pass. Report the file and hunk. Never guess at a logic merge; the cost of asking is one message, the cost of a wrong merge is a shared branch.
5. Remove the temporary worktree when done.

Name every resolution you made in the report ("resolved set-add in `convert.py`: kept both `fur` and `nmi`").

### 3. Merge the PR

```bash
gh pr merge <number> --merge --delete-branch \
  --subject "Merge <branch>: <pr title> (#<number>)"
```

- `--merge` gives a merge commit with the branch history intact. `--squash` only when Section 1's probe said the repo is squash-only — and then the subject is the squash convention, `<pr title> (#N)`, not the `Merge <branch>: …` form, which describes a merge commit that does not exist.
- **Always pass `--subject`.** Without it `gh` writes `Merge pull request #N from owner/branch`, which drops the title from `git log --oneline`. House format: `Merge <branch>: <pr title> (#N)`. A repo whose own merge history uses a different shape wins — copy it.
- Get the subject right the first time. Fixing a landed subject means a force-push to a shared branch; don't. If it landed wrong, say so and move on.
- Never `--admin`. Never merge red. Never merge over an unresolved Section 2.0 gate.

Record the merge SHA: `gh pr view <number> --json mergeCommit --jq .mergeCommit.oid`.

If the merge command is denied by the classifier, Section 0a applies: stop here, log `blocked`, report the exact command.

If `--delete-branch` failed because the branch is held by a worktree, the merge still happened — continue to 4a.

### 4. Clean up local state

```bash
git checkout <base-branch>
git pull --prune
git branch -d <merged-branch>
git fetch --prune
git branch -a          # verify: no remotes/origin/<merged-branch> remains
```

`--prune` is not optional: `--delete-branch` removes the remote branch, but the local `remotes/origin/<branch>` tracking ref stays until pruned, and a later session reading `git branch -a` will think the cleanup never happened. Say "pruned" only after `git branch -a` has come back clean.

**Always run `git worktree list` here**, whether or not anything failed. If any worktree — in this checkout or beside it — is checked out on the merged branch, it is part of the cleanup: `git worktree remove -f -f <path>` then `git worktree prune`, before `git branch -d`. A worktree left behind keeps a deleted branch alive and is the stale-branch mistake this section exists to prevent. Report "worktrees: none" only after the list is clean.

#### 4a. Branch held by a worktree

1. `git worktree list` — find the path holding the branch.
2. `git worktree remove -f -f <path>` (double `-f` clears agent-set locks).
3. `git branch -D <branch>`, `git worktree prune`, then the main-path cleanup above, ending with `git branch -a`.
4. If the remote branch was not deleted (the merge's `--delete-branch` failed), delete it: `git push origin --delete <branch>`. If that is denied, Section 0a: record the SHA, hand the user the `!` command, continue.

If `cd` into the worktree errors ("Unable to read current working directory"), work from the main repo path.

#### 4b. Base branch checked out elsewhere

`'<base>' is already used by worktree at '...'` → you are inside a different worktree. Run the cleanup from the main repo path; it is the canonical home of the base branch.

#### 4c. Final state

"On `<base>`, up to date. Deleted local `<branch>`, pruned `origin/<branch>`." If the run began inside a feature-branch worktree, confirm the main worktree is back on the base branch.

### 5. Label linked issues `status: staged` (project-conditional)

Applies when the repo uses the `status:` label namespace **and** the PR merged into a non-default branch (e.g. `dev` while default is `main`). Detect: `gh label list --repo <owner/repo> --search "status:" --json name --jq '.[].name'` — proceed if `status: staged` exists.

1. `gh pr view <number> --json body,closingIssuesReferences --jq '.closingIssuesReferences[].number'`; if empty, grep the body for `#\d+` near closes/fixes/resolves.
2. For each issue: `gh issue edit <N> --repo <owner/repo> --add-label "status: staged" --remove-label "status: wip" --remove-label "status: ready" --remove-label "status: triage"`. Strip **every** upstream lane; removing a label the issue lacks is a harmless no-op.
3. No references → skip silently.

The release PR's `Closes #N` lines later auto-close these and the repo's `clean-status-on-close.yml` (where installed) strips the label; Section 6 step 5 sweeps defensively.

### 5b. Log the run (every path, including a stop)

Append one row before writing the report. The script lives beside this file; call it by that path (in a global install `~/.claude/skills/stone-merge/log-run.sh`, in a project install `.claude/skills/stone-merge/log-run.sh`):

```bash
<skill-dir>/log-run.sh --pr <N> --base <branch> --outcome merged \
  --sha <merge-sha> --gate docs-only --checks pass --conflicts none \
  --labels "#12 #13" --classifier none --merged-from subagent
```

- `--outcome`: `merged`, `stopped`, or `blocked`.
- `--gate`: `docs-only`, `ci-check`, `reviewer:<name>`, `policy-optional`, `asked`, or `waived`.
- `--checks`: `pass`, `fail`, `none`, `rerun-passed`.
- `--classifier`: the **verbatim** denial text when anything was blocked, else `none`.
- `--merged-from`: `subagent` when you are the dispatched agent, `main` when the skill ran inline in the user's session, `script` or `auto` if a future shape applies. This field is what finally lets the log see where merges run.
- `--note`: what blocked a stopped run.

Rows land in `${XDG_STATE_HOME:-$HOME/.local/state}/stone-merge/runs.jsonl` (override: `STONE_MERGE_LOG`). The script is fail-open; a logging failure never costs a merge and is not reported as a run failure. A stopped run is the more valuable row — log it.

### 6. Promotion to the release branch (keyword-gated)

**Default: no promotion, and no mention of it.** Promote only when the quoted invocation itself contains `prod`, `production`, `release`, `ship to prod`, `merge and release`, "to main", or "to master". Absent that, the report ends after Section 5b and says nothing about releasing. An unprompted "want me to release?" on every merge is noise, and it invites a yes nobody had thought about.

When the invocation carries the keyword:

1. Detect the release branch — the permanent branch that is not the integration default:
   ```bash
   RELEASE=$(git show-ref --verify --quiet refs/remotes/origin/main && echo main || echo master)
   ```
2. `git log origin/<release>..origin/dev --oneline` — what is being promoted.
3. Create the release PR. The body must carry a `Closes #N` line for **every** issue staged by the commits being promoted (Section 5's labels are how you find them: `gh issue list --label "status: staged" --json number`):
   ```bash
   gh pr create --base <release> --head dev --title "<title>" --body-file - <<'EOF'
   ## Summary
   - <bullets summarising the promoted commits>

   Closes #N
   Closes #M
   EOF
   ```
4. Section 2 applies to the release PR (watch, one flake rerun, never red). Then merge it **without** `--delete-branch` — `dev` is permanent:
   ```bash
   gh pr merge <release-pr> --merge --subject "Merge dev: <title> (#<release-pr>)"
   ```
   If this merge is denied by the classifier, Section 0a applies with one difference: report the exact command **to the dispatching session**, which runs that single merge itself. Say so plainly in the report: "release merge denied in the agent; the command is: …". Do the sweep (step 6) and the log row anyway if the dispatching session confirms the merge; otherwise leave them for it.
5. `git checkout dev && git pull` — work continues on `dev`.
6. **Staged-label sweep.** `gh issue list --repo <owner/repo> --state all --label "status: staged" --json number --jq '.[].number'`; for each, if its PR is now in `<release>` (`gh pr list --search "<N> in:body is:merged base:<release>"`), `gh issue edit <N> --remove-label "status: staged"`. Leave issues whose PRs have not shipped.
7. Log the promotion as its own row: `--pr <release-pr> --base <release> --outcome merged --sha <sha> --checks pass --classifier none --merged-from subagent --note promotion`.
8. Report: "Merged to `<release>` (`<sha>`). Stripped `status: staged` from N issues."

**Never force-push `<release>` or `dev`. Never `--admin` a release PR. Never delete `dev` or `<release>`.**

### 7. The report

One message. It is the only thing the user sees of this run, so it must stand alone.

- **Lead with any blocker**: a failed check with its excerpt, an unfamiliar conflict, a review finding that needs a human, a denial quoted verbatim with the exact `!` command to finish.
- Then, briefly: PR(s) merged with SHA and merge subject; how the review gate resolved (`docs-only`, `ci-check`, `reviewer:<name>` with findings applied, `policy-optional`, `waived`); conflicts resolved and how; cleanup state (base branch, deleted, pruned, `git branch -a` clean); issues labelled; promotion result if asked; the log row written.
- Say nothing about promotion unless the invocation asked for it.

The dispatching session relays this. Only two items in it call for further action there: a Section 2.0 rung-4 question, and a denied release merge (Section 6 step 4). Everything else is finished.

**When the agent reports a denied release merge**, the main session runs exactly that one command itself — the user asked for the release in their own words, and the release PR is already green — then relays the result with the agent's denial quoted. No extra checks first, and no question back to the user: one `gh pr merge` call, then the report.

**When the user answers the rung-4 question**, the main session spends at most three calls: write `project_review_policy.md` (body `review: <value>`) into the memory directory named in 2.0 rung 3, append its one index line to `MEMORY.md` there with a single shell `printf >>`, and dispatch a **fresh** agent with the same brief plus the line `Recorded review policy: review: <value>`. Do not resume the earlier agent and do not run the merge yourself.

## Arguments

- `/stone-merge` — merge the current branch's PR
- `/stone-merge 45` — merge PR #45
- `/stone-merge 45 88 91` — merge several PRs sequentially in the order given; expect later ones to go `CONFLICTING` once a sibling lands (Section 2d)
- `/stone-merge prod`, `/stone-merge and release`, "merge and release" — merge, then promote to the release branch (Section 6)
- `/stone-merge --no-review` — waive the Section 2.0 gate for this run; combinable with the above

## Safety

- Never merge a PR with failing checks; one rerun, only for a clearly unrelated flake.
- Resolve the review gate on its ladder before merging code; merge over findings only when the user waived them in the invocation.
- `CHANGES_REQUESTED` and `REVIEW_REQUIRED` stop the run. Never `--admin`.
- Promote only on a keyword in the user's own invocation; never offer it.
- Briefs carry facts, never granted authority.
- A classifier denial is reported verbatim, never routed around (Section 0a).
- Rebase and `--force-with-lease` only the feature branch being merged; never a protected or permanent branch.
- Always leave the user on the base branch with the merged branch deleted and pruned.
- Never delete `dev` or the release branch.
- Do not refresh or commit a knowledge graph (graphify) here; that rides the PR at commit time.
