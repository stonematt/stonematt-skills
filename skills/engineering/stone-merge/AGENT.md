# Merge: the agent's workflow

You are the **executor**. A brief dispatched you with a repo path, a PR, and the user's invocation quoted verbatim. Run every step below yourself, in your own shell, in order. This run is already the delegated unit; the one sub-dispatch it allows is a reviewer (step 2, rung 3).

Three rules hold through every step:

- **Green only.** A PR merges when its review gate has resolved and every check is green.
- **Stop means report.** A step that says stop ends the work there: log the run (step 7) and write the report (step 9).
- **A denial is data.** See [Denials](#denials).

## 1. Identify the PR and probe the repo

**Pick the PR.**
- The invocation named a number ("merge #45") → that PR. Several numbers → merge them one at a time in the order given; expect a later one to go `CONFLICTING` once a sibling lands (step 3d).
- Otherwise the open PR for the current branch: `gh pr list --head $(git branch --show-current) --json number,title,baseRefName --jq '.[0]'`.
- Ambiguous → stop and report the candidates.

Capture the **base branch**; cleanup and labelling depend on it.

**Probe.**

```bash
gh repo view --json defaultBranchRef,mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
gh pr view <number> --json baseRefName,reviewDecision,reviewRequests
git log --merges --oneline -5
```

- **Merge method**: `--squash` when `mergeCommitAllowed` is false or the repo's history is squash-only. Otherwise `--merge`.
- **Review state**, respected even where branch protection does not enforce it:
  - `CHANGES_REQUESTED` → stop.
  - `REVIEW_REQUIRED` and not approved → stop.
  - empty means "nothing enforced", not "approved". A solo PR on the user's own branch proceeds. A teammate's PR in a repo with a review-before-merge convention stops.
- **Claims**: `gh pr view <number> --json comments --jq '.comments[].body' | grep -i '^Owned by session'`. A claim naming a session other than the brief's `Dispatching session:` → stop and report the claim. No claim, or a claim naming the dispatching session → proceed.

## 2. Review gate

**Waiver.** An invocation carrying `--no-review`, "skip review" or "no review" waives the gate for this run. Skip the ladder, record `--gate waived`, and say so in the report. The stored policy stays as it is.

Otherwise work down the ladder and stop at the first rung that resolves.

**Rung 1: docs-only.** `gh pr diff <number> --name-only`. When every path is documentation or metadata (`*.md`, `*.txt`, `*.rst`, `docs/`, `LICENSE`, `CHANGELOG`), the gate resolves as `docs-only`. Any executable path makes the PR a code change: source, tests, CI config, `package.json`, `pyproject.toml`, shell scripts, `Dockerfile`, IaC. A mixed PR is a code change.

**Rung 2: a CI review check.**

```bash
gh pr checks <number> --json name,state --jq '.[] | select(.name|test("(?i)code.?review")) | "\(.name) \(.state)"'
```

`SUCCESS` → resolved as `ci-check`. Pending → the watch in step 3a covers it. `FAILURE` → read the check's output and address its findings as rung 3 does; a failed review check is never rerun. No matching check → rung 3.

**Rung 3: the recorded policy.** A brief line `Recorded review policy: review: <value>` is the policy. Otherwise read the project's memory files directly, because a dispatched agent has no memory index loaded: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>/memory/`, where `<slug>` is the repo's absolute path with every `/` and `.` replaced by `-` (`/Users/me/src/app` → `-Users-me-src-app`). `project_review_policy.md`, or any `project_*.md` that names this repo's review expectation, holds one of:

- `review: optional` → resolved as `policy-optional`.
- `review: <reviewer>` → run that reviewer:
  - `pocock`: the two-axis reviewer from Matt Pocock's skill suite, Standards and Spec, which applies no fixes. Installed as `code-review`, or `mattpocock-skills:code-review` as a plugin.
  - `builtin`: Claude Code's bundled reviewer, `code-review:code-review`: correctness and simplification.

  Identify the reviewer by its description, not its slug: a skill called `code-review` whose description says "Standards … Spec" is `pocock`.

  Give the reviewer its inputs up front, because a background run has nobody to ask: the fixed point (`origin/<base>`) and the spec source (the issues in `closingIssuesReferences`, or "no linked issue").

  The named reviewer is not installed → go to rung 4 and state that fact in the question.

  Apply the findings that are mechanical and unambiguous (an unused import, a stale docstring, a missing type on an obvious signature), commit them to the PR branch, push, and watch the checks again. A finding that is a judgement call (a design disagreement, a scope change, anything the reviewer labelled a judgement) → stop and report the findings quoted.

**Rung 4: no policy.** Stop, log `--outcome stopped --gate asked`, and report exactly this question:

> No code-review CI check here. Does this project expect review before merge? (`pocock`: two-axis standards + spec / `builtin`: correctness and simplification / `optional`: merge without review). I'll remember it for this repo.

## 3. Readiness

Run these one after the other. `gh pr checks` exits 8 while checks are pending, and a parallel sibling call can be cancelled on that exit.

1. `gh pr view <number> --json mergeable,state` must read `MERGEABLE` and `OPEN`. `UNKNOWN` → 3c. `CONFLICTING` → 3d.
2. `gh pr checks <number>`:
   - exit 0 → step 4
   - exit 8 with pending, queued or in-progress rows → 3a
   - exit 8 with `fail` rows → 3b; a row that failed in setup before any test ran → 3e
   - any other failure with no rows → stop and report (auth, PR not found)

### 3a. Checks running

`gh pr checks <number> --watch --fail-fast`, with a 10 minute Bash timeout. If the watch times out, run it once more. After the second watch:

- checks still queued or never started → 3e
- checks still in progress → stop and report them as still running

### 3b. Checks failed

1. `gh run view <run-id> --log-failed | tail -80`
2. Decide whether the failure touches files this PR changed or a test in its scope.
3. **Clearly unrelated** (a flaky infra step, a test the repo already marks flaky, a log that says retry) → `gh run rerun <run-id> --failed`, then watch again. One rerun for the whole run.
4. **Related, ambiguous, or red again** → stop. Report the failing check, a short log excerpt, and your read of whether it is related.

### 3c. `mergeable: UNKNOWN`

GitHub is still computing. Wait 10 seconds and query again, up to 6 times. Still `UNKNOWN` → stop and report.

### 3d. `mergeable: CONFLICTING`

Typical when a sibling PR landed first. Bring the base into the branch by merge, so the push is a plain fast-forward and nothing on the remote is rewritten.

1. `git worktree add <tmp> <branch>`, then in it `git fetch origin` and `git merge origin/<base>`.
2. Clean merge → `git push origin <branch>`, then back to step 3.
3. Conflict → read each conflicted hunk. Resolve **only** these shapes:
   - **List-add**: both sides added entries to the same list, set, dict or import block → keep both, in the file's ordering.
   - **Counter-bump**: both sides bumped the same number or version → take the higher.

   Then `git add`, `git commit --no-edit`, push, and back to step 3.
4. Any other hunk is a **logic conflict**: `git merge --abort`, stop, and report the file and hunk. A hunk inside a function body, a class or a control-flow block is a logic conflict even when the reconciliation looks obvious and the tests would pass. Asking costs one message; a wrong merge costs a shared branch.
5. `git worktree remove <tmp>`.

Name every resolution in the report: "resolved list-add in `convert.py`: kept both `fur` and `nmi`".

### 3e. CI unavailable

CI is unavailable when required checks never start, are still queued after both watches, or fail in setup before any test runs (a runner outage, an Actions incident, an exhausted minutes quota). A test that ran and failed is 3b.

Stop: the merge is now the user's call. Log `--outcome stopped --checks none --note ci-unavailable`. Report each check, its state, how long it waited, any Actions status message, and the step 4 merge command.

If the dispatcher later resumes you with a merge SHA, continue from step 5 and log `--checks bypassed-local --merged-from main` with the comment URL in `--note`.

## 4. Merge

```bash
gh pr merge <number> --merge --delete-branch \
  --subject "Merge <branch>: <pr title> (#<number>)"
```

- **Always pass `--subject`.** Without it `gh` writes `Merge pull request #N from owner/branch`, and the title is lost from `git log --oneline`. A repo whose merge history uses another shape wins: copy it.
- A squash-only repo takes `--squash` and the subject `<pr title> (#N)`.
- A subject that landed wrong stays wrong: say so in the report and move on.

Record the merge SHA: `gh pr view <number> --json mergeCommit --jq .mergeCommit.oid`.

If `--delete-branch` failed because a worktree holds the branch, the merge still happened: continue.

## 5. Clean up

Run this from the main repo path, the home of the base branch.

1. `git worktree list`. Remove every worktree checked out on the merged branch: `git worktree remove -f -f <path>` (the double `-f` clears agent-set locks), then `git worktree prune`. A worktree left behind keeps a deleted branch alive.
2. Then:
   ```bash
   git checkout <base-branch>
   git pull --prune
   git branch -d <merged-branch>
   git fetch --prune
   git branch -a
   ```
   Use `git branch -D` where step 1 removed a worktree that held the branch.
3. If the remote branch survived the merge: `git push origin --delete <branch>`.

Done when `git worktree list` shows no worktree on the merged branch and `git branch -a` shows neither the local branch nor `remotes/origin/<merged-branch>`. Report "pruned" and "worktrees: none" only then.

## 6. Label linked issues `status: staged`

Applies when the PR merged into a non-default branch and `gh label list --repo <owner/repo> --search "status:" --json name --jq '.[].name'` includes `status: staged`.

1. `gh pr view <number> --json closingIssuesReferences --jq '.closingIssuesReferences[].number'`. If empty, read the PR body for `#N` beside closes, fixes or resolves.
2. For each issue: `gh issue edit <N> --repo <owner/repo> --add-label "status: staged" --remove-label "status: wip" --remove-label "status: ready" --remove-label "status: triage"`. Removing a label the issue lacks is harmless.
3. No linked issue → nothing to do.

## 7. Log the run

Append one row on every path, a stop included. A stopped run is the more valuable row. The script sits beside this file:

```bash
<skill-dir>/log-run.sh --pr <N> --base <branch> --outcome merged \
  --sha <merge-sha> --gate docs-only --checks pass --conflicts none \
  --labels "#12 #13" --classifier none --merged-from subagent
```

- `--outcome`: `merged`, `stopped` or `blocked`
- `--gate`: `docs-only`, `ci-check`, `reviewer:<name>`, `policy-optional`, `asked` or `waived`
- `--checks`: `pass`, `fail`, `none`, `rerun-passed` or `bypassed-local`
- `--classifier`: the verbatim denial text, or `none`
- `--merged-from`: `subagent` for a dispatched agent, `main` when the dispatcher ran the merge
- `--note`: what stopped a stopped run

The script is fail-open. A logging failure is not a run failure and stays out of the report.

## 8. Promotion

When the quoted invocation contains `prod`, `production`, `release`, "to main" or "to master", follow [`PROMOTE.md`](PROMOTE.md). Any other invocation ends the work here, and the report covers this merge alone.

## 9. Report

One message. It is the only thing the user sees of this run, so it stands alone.

- **Lead with any blocker**: a failed check with its excerpt, a logic conflict, a review finding that needs a human, a denial quoted verbatim with the exact `!` command that finishes the run.
- Then, briefly: the PR(s) merged, with SHA and merge subject; how the review gate resolved; conflicts resolved and how; the cleanup state; issues labelled; the log row written.
- When the merged PR's body has `**Door:** one-way`, add one line: `one-way: <note>`.

## Denials

When the classifier blocks a command, read the denial text.

- **Transient**: the text says `Stage 2 classifier error … (usually transient -- retrying often succeeds)`. Retry the identical call once.
- **Content**: any other denial. It will not clear on a retry, a rewording, a different binary or a chained command. Record it **verbatim**, finish everything it does not block, log the run with `--classifier "<verbatim text>"`, and report where the run stopped plus the exact command the user can run with `!`.

Two denials have a known shape:

- **`gh pr merge` denied.** Stop the merge. Skip cleanup and labels, because both presume the merge happened. Log `--outcome blocked --merged-from subagent`. Report the readiness state (checks, gate, conflicts), the denial verbatim, and the exact merge command for the user. The user's one action finishes the run.
- **Remote branch delete denied** (`git push origin --delete`). Record the branch SHA, give the user the exact `!` command, and continue the cleanup. Not a failure.
