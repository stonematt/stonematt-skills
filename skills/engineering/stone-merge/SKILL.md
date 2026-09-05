---
name: stone-merge
description: Merge a pull request, clean up the branch, and optionally promote to production. Use this skill whenever the user wants to merge a PR — including /stone-merge, "merge it", "merge the PR", "land it", "merge and release", "merge to prod", "ship to production", or any confirmation after checks pass. Also trigger when the user says "merge after checks", "merge when green", or refers to merging + deploying in the same breath. This is the counterpart to /stone-commit — commit gets code ready, merge lands it and cleans up.
---

# Merge Skill

The post-commit counterpart to `/stone-commit`. Handles the full lifecycle after code is ready: wait for checks, merge the PR, clean up the branch, and optionally promote to production.

The work is procedural — gated waits on `gh pr checks --watch`, log triage, branch bookkeeping — and none of it benefits from Opus reasoning. Dispatch it to a sonnet subagent. The one step that stays with you is `gh pr merge` itself; see Section 0.

## 0. Dispatch the wait, keep the merge

`/stone-merge` costs the main session three tool calls: dispatch a sonnet subagent for readiness, run `gh pr merge` yourself, hand the same agent the cleanup. The user ran this skill to stop thinking about the merge and go start something else — the gated wait and the log triage are what they actually wanted off their hands. Staying resident to sequence every step defeats that as thoroughly as running the whole thing inline.

**The subagent owns Sections 1–2 and 4–5b.** Readiness, checks watch, review gate; then branch cleanup, `status:` labels, run log. **You own Section 3 — the `gh pr merge` command — and Section 6 if promotion was asked for.** That split is not fastidiousness about irreversible acts; it is what the classifier permits (below).

**Why the merge command stays here.** Two different gates get called "the classifier," and conflating them costs a run:

- **The dispatch brief.** Verified 2026-09-03: a brief reading "PROD PROMOTION IS AUTHORIZED… merge to main, review gate waived" was denied; read-only briefs passed twice, same agent type and model. Authority language in the brief is what trips this one, so it is fixable by rewording.
- **The tool call a subagent makes mid-run.** Verified 2026-09-05 on `mcp-obsidian-cli`: `gh pr merge` was denied twice from subagents and zero times from the main session — same command, same repo, same session, feature PRs into `dev`, no promotion anywhere in the brief. Every merge that landed that session landed from main. The dispatch itself succeeded; the block arrives later, on the merge call. **No brief wording reaches this one.** Don't spend a run rediscovering that.

So: keep `gh pr merge` here by default, and do not write a brief that asks a subagent to run it.

**Resume the same agent rather than re-briefing.** After the merge, `SendMessage` the readiness agent with the merge SHA and `"merged; proceed with Sections 4-5b"`. It still holds the PR numbers, base branch, and repo path. Dispatch a second agent only if resume is unavailable.

**Background by default.** `run_in_background: true` is what actually frees the user; a foreground dispatch parks them exactly as a foreground `--watch` would. Go foreground only when they said they're waiting on the result.

**How to dispatch.** `subagent_type: "general-purpose"`, `model: "sonnet"`, `description: "Ready PR #<num> to merge"`. The brief carries the PR number(s), base branch, repo path (a subagent doesn't inherit `cwd` the way you might assume), the user's invocation quoted verbatim, and the directive `"Load the merge skill at ~/.claude/skills/stone-merge/SKILL.md and execute Sections 1-2. Skip Section 0. Do not run gh pr merge — report the exact command instead."` Ask it to report: go/no-go, the verbatim merge command it would have run, check results, conflicts resolved and how, the review-gate outcome, and whether anything came back blocked by the classifier (quoted verbatim if so).

The resume message (Sections 4–5b) carries the merge SHA, and adds Section 6 only when the invocation carried a promotion keyword — Section 6's own merge still comes back to you.

**Quote the invocation as a fact** — `the invocation was: /stone-merge prod` — and let the subagent apply Section 6's keyword rule to it itself. Briefs that grant ("prod promotion is authorized", "review gate waived") are the shape that gets denied.

**Run the sections inline instead when** you are already a subagent, the Agent tool is unavailable, or the user asked you to stay in this context. Inline still stops at Section 3 if you are a subagent — do the readiness and the cleanup yourself, but the merge command goes up to your parent, not into your own shell.

### 0a. When the classifier blocks anyway

**Read the denial text — it names which kind of block it is.**

A **transient** block says so: `Stage 2 classifier error - blocking based on stage 1 assessment (usually transient -- retrying often succeeds)`. That is infrastructure, not judgment — retry the identical call once. Observed 2026-09-04: a read-only `gh pr view 104 --json mergedAt,mergeCommit,state,number` was denied, then succeeded verbatim, nothing about its shape changed. One retry is the whole allowance; a transient denial that repeats is a content block wearing the wrong label.

A **content** block instead names the authority-shaped thing it objected to, and will not clear on retry. Change the *shape* of the approach. Do not hunt for a permission rule to add — a content classifier does not read permission rules, so adding one is motion without progress.

- **A dispatch was denied.** The brief carried authority language. Re-cut it to facts-and-findings, or pull that one step back into the main session. A denial should cost one step, not the whole delegation — never collapse the entire fan-out back into main context over a single block.
- **`gh pr merge` was denied inside a subagent.** Expected (Section 0), not a brief defect. Do not retry it, do not reword anything, do not look for a permission rule to add. Report the exact command plus the readiness state to the parent and stop there; the parent runs the merge and resumes you for cleanup. One attempt is the whole allowance — and if you are the subagent, the cheaper move is not to attempt it at all.
- **A privileged action was denied in the main session** (a `Skill(update-config)` call, a heredoc rewriting `~/.claude/CLAUDE.md`). Retry through the naturally appropriate tool instead — read the file directly, then `Edit` it.
- **Remote-state deletion was denied** (`git push origin --delete`, Section 4 cleanup). This one is expected — deleting remote state is on the classifier's list. Don't loop. Record the branch SHAs for recoverability, hand the user the exact command to run with `!`, and continue with the rest of the cleanup.

Report the block plainly and move on. Never route around it with a different binary to accomplish the same denied action.

## Workflow

### 1. Identify the PR and probe repo conventions

**Pick the PR.** Determine which PR to merge:
- If the user provided a PR number (e.g., "merge #45"), use that
- If on a feature branch, find the open PR for it: `gh pr list --head $(git branch --show-current) --json number,title,baseRefName --jq '.[0]'`
- If ambiguous, ask

Capture the **base branch** (where the PR merges into) — you'll need it for cleanup.

**Probe conventions.** Repos differ. Before merging in an unfamiliar repo, check:

```bash
gh repo view --json defaultBranchRef,mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
gh pr view <number> --json baseRefName,reviewDecision,reviewRequests
```

Note the result and adapt:
- **Merge method**: if `mergeCommitAllowed: false` and the project history is squash-only, use `--squash` instead of `--merge`. Don't fight a repo's policy.
- **Review state (respect even when protection isn't enforced)**: `reviewDecision` is one of `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, `APPROVED`, or **empty** (no branch protection — common on private/free-tier repos). Rules:
  - `CHANGES_REQUESTED` → **stop**. A reviewer asked for changes; never merge over them, never `--admin` to bypass.
  - `REVIEW_REQUIRED` and not approved → **stop** and tell the user.
  - **empty** → means "nothing enforced," **not** "approved." If the PR is a teammate's, or the repo follows a review-before-merge convention, do **not** silently self-merge — confirm with the user that review is done or waived first. Solo PR on your own branch with no such convention: proceed.
- **Default branch vs base**: if base is the default branch, the kanban-staging step (Section 5) is skipped — there's no staging to label.

### 2. Check readiness

#### 2.0 Preflight: code-review gate (run first)

Work down this ladder in order and stop at the first rung that resolves. Most PRs resolve on rung 1 or 2 without asking anyone anything.

**1. Docs-only? Skip the gate.** Inspect what actually changed:

```bash
gh pr diff <number> --name-only
```

If every path is documentation or metadata — `*.md`, `*.txt`, `docs/`, `LICENSE`, `CHANGELOG`, `*.rst` — skip review and go to 2.1. No prompt, no waiver to record, just a line in the final report saying it was docs-only. A prose diff has no correctness surface worth an agent's time.

Any executable path in the set — source, tests, CI config, `package.json`, shell scripts, `Dockerfile`, IaC — makes it a code change. Mixed PRs are code changes.

**2. CI-check mode.** If the repo runs `/code-review` as a GitHub Action — a check whose name matches `code.?review` — that check is the gate:

```bash
gh pr checks <number> --json name,state --jq '.[] | select(.name|test("(?i)code.?review")) | "\(.name) \(.state)"'
```

- `SUCCESS` → continue to 2.1.
- `PENDING`/`IN_PROGRESS`/`QUEUED` → the watch loop (2a) covers it; note it and proceed.
- `FAILURE` → treat as a failed check (2b). Read the review output and address the findings; merging over them is what this gate exists to prevent.
- No matching check → rung 3.

**3. Project policy, remembered.** Repos differ on this and the difference is stable, so learn it once per repo instead of asking every merge. Look for a recorded policy in the project's auto-memory (a `project_*.md` naming this repo's review expectation). Two values:

- `review: optional` → skip and merge. Note it in the report.
- `review: <reviewer>` → run that reviewer, then merge. The policy names *which* one, because "code review" resolves to several different things and picking by vibe gives a different review each run:
  - `pocock` — `mattpocock-skills:code-review`. Two axes in parallel: Standards (repo conventions plus a Fowler smell baseline) and Spec (does the diff do what the originating issue asked). Reports the axes separately and applies no fixes. Best where scope creep and spec drift matter.
  - `builtin` — the `code-review` skill. Correctness bugs plus reuse and simplification, at an effort level. Takes `--fix` to apply findings to the working tree. Best where the risk is a bug rather than a divergence from spec.

  **Pre-supply the inputs or it stalls.** Both reviewers ask the user for missing context, and a background dispatch has nobody to ask. Hand the reviewer the fixed point (`origin/<base-branch>`, so the diff is against the merge-base) and the spec source (the issues Section 5 extracts from `closingIssuesReferences`). If no issue is linked, say so in the brief — `pocock` skips its Spec axis and reports that, rather than blocking.

  Apply findings that are mechanical and unambiguous, commit them to the branch, and re-watch checks. Escalate the judgment calls — a design disagreement, a finding implying a scope change, anything `pocock` labelled a judgement call rather than a hard violation — quoting the finding. Then merge.

**4. No policy recorded? Ask once, then write it down.** First code-change merge in an unfamiliar repo:

> "No code-review CI check here. Does this project expect review before merge? (`pocock` — two-axis standards + spec / `builtin` — correctness and simplification, can auto-fix / `optional` — merge without review). I'll remember it for this repo."

Record the answer as a project memory so rung 3 resolves it from here on. If the user declines to set a policy, treat it as `optional` for this run and ask again next time rather than guessing a default.

**Bypass.** `/stone-merge --no-review` waives the gate for one run without touching the stored policy. Record the waiver in the final report.

#### 2.1 Readiness checks

Run **sequentially**, not in parallel. `gh pr checks` exits non-zero when any check is still pending or has failed (exit 8 = pending). If you launch it as a parallel sibling to `gh pr view`, the harness sees one tool error and may cancel the other call mid-flight, costing you both signals at once. Run them one after the other so you can interpret each exit code on its own:

1. `gh pr view <number> --json mergeable,state,baseRefName,reviewDecision` — must be MERGEABLE and OPEN, and `reviewDecision` must not be `CHANGES_REQUESTED` (apply the Section 1 review-state rule — stop if a reviewer requested changes, or if an empty decision needs the user's go-ahead per convention)
2. `gh pr checks <number>` — interpret exit code:
   - **Exit 0**: all checks pass → proceed to Section 3 merge
   - **Exit 8 with status `pending`/`queued`/`in_progress` rows**: checks still running → go to 2a (watch loop)
   - **Exit 8 with status `fail` rows**: a real failure → go to 2b
   - **Other non-zero with no rows**: PR not found or auth issue → stop and report

If `mergeable` came back `UNKNOWN`, see 2c before checking checks — GitHub may not have finished computing.

#### 2a. Checks still running

```bash
gh pr checks <number> --watch --fail-fast
```

`--watch` blocks until terminal state. Set the Bash timeout generously (10 min is reasonable for most repos with e2e); CI longer than that suggests something is stuck and the user should investigate. If the watch itself hits the harness timeout, retry once with a longer timeout before escalating — don't conclude the PR is broken just because the wait was long.

#### 2b. Checks failed

Don't merge a red PR — but distinguish a real failure from an unrelated flake before bailing:

1. Read the failed step's log: `gh run view <run-id> --log-failed | tail -80`
2. Ask: does the failure touch files this PR changed? Does the test name relate to the PR's scope?
3. **If clearly unrelated** (e.g. e2e on `auth.spec.ts` failing on a docs-only PR, or "2 flaky / 1 failed" with the failed test in the flaky bucket on retry): re-run the failed job once with `gh run rerun <run-id> --failed`, then re-watch.
4. **If related, ambiguous, or fails again on re-run**: stop. Report the failure with the log excerpt and let the user decide.

Don't loop on re-runs — one re-run attempt, then escalate.

#### 2c. `mergeable: UNKNOWN`

GitHub takes a moment to recompute mergeability after the base branch advances. If the value is `UNKNOWN`, sleep 5–10 seconds and re-query. Don't treat `UNKNOWN` as `CONFLICTING`.

#### 2d. `mergeable: CONFLICTING` — rebase + retry

This commonly happens when a sibling PR merged first and both touched the same line (e.g. both unskip a row in a shared audit-test set). Attempt resolution before bailing:

1. Check out the PR's branch (typically requires a worktree — see Section 4 for collision handling).
2. `git fetch origin` then `git rebase origin/<base-branch>`.
3. If clean, force-push: `git push --force-with-lease origin <branch>`. Re-watch checks. Done.
4. If conflict, read the conflicted file. Look for **shape-recognizable patterns**:
   - **Set/list-add collisions**: both branches added entries to the same `Set<...>([...])` or array literal. Resolution: union the entries, alphabetize/preserve order convention from the file.
   - **Import-list collisions**: both added imports from the same module. Resolution: merge both import lines.
   - **Counter/version-bump collisions**: both bumped the same number. Resolution: pick the higher value (or whichever the user's convention prefers — ask if unclear).
5. After editing: `git add <file>` then `git rebase --continue`. Then force-push and re-watch checks.
6. **If the conflict isn't a recognized pattern** (logic conflict, semantic conflict, multiple files): stop. Report the conflict location and let the user resolve. Don't guess at logic merges.

When running the rebase from inside a git worktree (typical when you isolated work), `cd` into the worktree dir before the rebase commands so you operate on the correct ref. Bash sessions in this harness do not persist `cd` between calls — chain the `cd` in the same command (using `&&` is fine here for non-git commands; for git commands use the worktree path implicitly via `git -C <path>`).

### 3. Merge the PR

Merging a feature PR into `dev` needs no escalation for *authority* — but the `gh pr merge` command runs in the main session whatever the target branch, because a subagent's merge call gets denied (Section 0). A release PR to `main`/`master` escalates on both counts.

```bash
gh pr merge <number> --merge --delete-branch
```

Use `--merge` (not `--squash` or `--rebase`) which creates a merge commit with `--no-ff` behavior, preserving the full branch history. The `--delete-branch` flag removes the remote branch.

If repo policy forbids merge commits (Section 1 probe surfaced this), use `--squash` instead. Never use `--admin` to bypass.

### 4. Clean up local state

This is the critical step that prevents stale-branch mistakes. After merge:

```bash
git checkout <base-branch>
git pull
git branch -d <merged-branch-name>
```

#### 4a. `--delete-branch` failed at merge time

`gh pr merge --delete-branch` fails when the merged branch is checked out by an active worktree. The PR is already merged — you just need to clean up the local refs. Recovery:

1. Find the worktree pinning the branch: `git worktree list` — look for the branch name in brackets.
2. Remove the worktree: `git worktree remove -f -f <path>` (double `-f` overrides locks set by background agents).
3. Delete the local branch: `git branch -D <branch>` (use `-D` since `-d` may complain about merge-tracking; the PR merge already confirmed the code landed).
4. Run `git worktree prune` to clean up any stale entries, then `git pull` on the base branch.

If the worktree is in a corrupted state (e.g. `cd` errors with "Unable to read current working directory"), `cd` to the main repo path first, then run prune + branch delete.

#### 4a-bis. Remote branch deletion blocked by the classifier

`git push origin --delete <branch>` is on the auto-mode classifier's list (deleting remote state) and may come back `Blocked by classifier` even for branches that are provably merged. Expected, not a misconfiguration. Per Section 0a:

1. Record the SHAs first so the branches stay recoverable: `git branch -r --format '%(refname:short) %(objectname)' | grep -E 'origin/(feat|fix)/'`
2. Verify merged-ness before proposing deletion — `git log --oneline origin/<base>..<branch>` returning zero commits means fully merged.
3. Hand the user the exact command to run themselves with `!`, and say which branches (if any) carry unmerged commits.
4. Continue with the remaining cleanup. Don't retry, and don't reach for a different binary to do the same delete.

#### 4b. Base branch checked out elsewhere

If `git checkout <base-branch>` fails with `'<base>' is already used by worktree at '...'`, you're trying to switch from inside a different worktree. Step out: `cd` to the main repo path, then run the cleanup. The skill assumes the main worktree is the canonical home for the base branch.

#### 4c. Final state

Confirm the cleanup: "On `<base-branch>`, up to date. Deleted local `<merged-branch>`."

If you launched the merge from inside a feature-branch worktree, the very first thing to verify after merge is that the main worktree is back on the base branch — sometimes parallel agent activity can leave it on the wrong ref.

### 5. Label linked issues `status: staged` (project-conditional)

If the repo uses the `status:` label namespace AND the PR merged to a non-default branch (e.g., `dev` while default is `master`), label its linked issues so the kanban view reflects "merged to staging, awaiting prod release".

Detect: `gh label list --repo <owner/repo> --search "status:" --json name --jq '.[].name'` — if `status: staged` exists, proceed.

Steps:
1. Extract issue refs from PR body: `gh pr view <number> --json body,closingIssuesReferences --jq '.closingIssuesReferences[].number'` (closing keywords like `Closes #N`, `Fixes #N`).
2. If `closingIssuesReferences` is empty, fall back to grepping the PR body for `#\d+` patterns near words like "closes/fixes/resolves" — some PRs reference issues without the precise keyword GitHub recognizes.
3. For each issue: `gh issue edit <N> --repo <owner/repo> --add-label "status: staged" --remove-label "status: wip" --remove-label "status: ready" --remove-label "status: triage"`. Strip **every** upstream lane, not just the expected one — a ticket can reach `staged` from any of them. Autonomous work often skips `wip` and merges straight from `ready`; a bug filed and fixed in one sitting never leaves `triage` (observed on #89, which merged via PR #90 still labelled `status: triage`). Removing a label the issue doesn't carry is a harmless no-op, and all three exist in the repo.
4. Skip silently if no references found — many PRs (docs, infra) won't have any.

When the release PR (dev→release branch) merges later, GitHub auto-closes via closing keywords and the `clean-status-on-close.yml` workflow strips the label. **But this only works if the release PR body uses `Closes #N` / `Fixes #N` / `Resolves #N` for every staged issue.** Section 6 step 5 has a defensive sweep for the case where keywords are missing or the workflow isn't installed.

### 5b. Log the run (every path, including a stop)

Append one row before you write the final report:

```bash
~/.claude/skills/stone-merge/log-run.sh --pr <N> --base <branch> --outcome merged \
  --sha <merge-sha> --gate docs-only --checks pass --conflicts none \
  --labels "#12 #13" --classifier none
```

The script is symlinked alongside this skill, so the same binary and the same log serve every repo. Rows land in `${XDG_STATE_HOME:-$HOME/.local/state}/stone-merge/runs.jsonl`. It is fail-open by design — a logging failure exits 0 and never costs a merge that already happened, so don't retry it or report its failure as a run failure.

`--outcome` is `merged`, `stopped`, or `blocked`. `--gate` records which rung of Section 2.0 resolved: `docs-only`, `ci-check`, `reviewer:<name>`, `policy-optional`, `asked`, or `waived`. Pass `--classifier` the **verbatim** denial text whenever the auto-mode classifier blocks anything, and `none` when it blocks nothing — an explicit `none` is what makes the absence of blocks countable later.

**A run that stopped is the more valuable row.** Log the failed check, the unfamiliar conflict, the review gate you couldn't satisfy, with `--outcome stopped` and a `--note` saying what blocked it. Those are the observations that decide whether the invariants need to move into hooks, and they are exactly the ones that evaporate from a background transcript nobody reads again.

Report honestly. You are writing your own report card, and a row that papers over a block is worse than a missing row.

### 6. Production promotion (gated)

**Default: do NOT auto-promote.** Production deploys are high-stakes shared-system changes. Per safe-action norms, modifying production needs explicit user authorization for *this specific action* — generic "auto mode" or background-agent invocation is not enough.

Promote only if the original prompt explicitly contains one of: `prod`, `production`, `release`, `ship to prod`, `merge and release`, or the user said "merge and release" / "to main" / "to master" in plain language.

**Absent that, stop after Section 5 and say nothing about promotion.** Report the merge and end. The user tracks their own release timing and will ask when they're ready; an unprompted "want me to release?" is noise on every ordinary merge, and it invites a yes to a question they hadn't thought about yet. Silence is the correct default here, not politeness.

When promotion is authorized:

**First, determine the release branch.** It's the permanent branch that is *not* the integration default (`dev`) — usually `main`, sometimes `master`. Never hardcode it; detect:
```bash
RELEASE=$(git show-ref --verify --quiet refs/remotes/origin/main && echo main || echo master)
```
Use that value wherever the steps below say `<release>`.

1. Check what's in `dev` but not `<release>`:
   ```bash
   git log origin/<release>..origin/dev --oneline
   ```

2. Create a release PR:
   ```bash
   gh pr create --base <release> --title "<title>" --body-file - <<'EOF'
   ## Summary
   - <bullets summarizing all commits being promoted>

   ## Test plan
   - [ ] <checklist items>
   EOF
   ```

3. Wait for checks (Section 2 rules apply, including flake re-run), then merge the release PR. Do NOT use `--delete-branch` on `dev` — `dev` is permanent.

4. Switch back to `dev` (not `<release>`) after the release merge — `dev` is where ongoing work continues.

5. **Strip `status: staged` from all linked issues (defensive cleanup).** If the repo has a `clean-status-on-close.yml` workflow, it handles this on issue-close — but only fires when the release PR's body uses closing keywords (`Closes #N`, `Fixes #N`, `Resolves #N`) that GitHub recognizes. If the release PR omits closing keywords, or the workflow isn't installed, the label sticks. Always run a sweep after the release merge:

   ```bash
   gh issue list --repo <owner/repo> --state all --label "status: staged" --json number --jq '.[].number'
   ```

   For each issue returned, verify its linked PR is now in `<release>` (`gh pr list --search "<N> in:body is:merged base:<release>"`). If yes, strip the label:

   ```bash
   gh issue edit <N> --repo <owner/repo> --remove-label "status: staged"
   ```

   Don't strip from issues whose PRs haven't actually shipped — those are correctly staged.

6. Log the promotion as its own row. The log is append-only, so a promotion is a second run rather than an amendment to the row Section 5b already wrote for the `dev` merge. The two rows don't share a strict join key — `ts` is set fresh at write time so it always differs, and `pr` differs by design (feature PR vs release PR) — correlate them by `repo` and proximity in time, or by `note: promotion` next to the nearest prior `merged` row for the same repo.

   ```bash
   ~/.claude/skills/stone-merge/log-run.sh --pr <release-pr> --base <release> \
     --outcome merged --sha <merge-sha> --checks pass --classifier none --note promotion
   ```

   Section 5b's field rules apply unchanged, `--classifier` included.

7. Confirm: "Merged to `<release>`. Production deploy rolling out at `<vercel/wherever URL if visible>`. Stripped `status: staged` from N issues."

**Never force push to `<release>`. Never use `--admin` on a release PR. Never delete `dev` or `<release>`.**

## Arguments

The skill accepts optional arguments after the command:
- `/stone-merge` — merge the current branch's PR (no prod promotion)
- `/stone-merge 45` — merge PR #45
- `/stone-merge 45 88 91` — merge multiple PRs sequentially in the order given (rebase-on-conflict applies for siblings that collide)
- `/stone-merge prod` or `/stone-merge production` — merge current PR then promote to production
- `/stone-merge and release` — same as above
- `/stone-merge --no-review` — waive the Section 2.0 code-review gate (trivial docs/infra PRs only); combinable with the above

When merging multiple PRs sequentially, expect later PRs to go `CONFLICTING` once an earlier sibling lands — handle each in turn per Section 2d.

## Subagent-mode notes

Section 0 dispatches readiness to a sonnet subagent by default, then resumes that same agent for cleanup after the parent merges. When you ARE that subagent, the user isn't watching your tool calls and often isn't waiting on them — the dispatch may be running in the background while they work on something else. Tighten the loop accordingly:

- **Finish your half of the run.** Sections 1–2 first: readiness, checks, review gate. Report go/no-go plus the verbatim `gh pr merge` command and stop — the parent runs it (Section 0), and hands you the SHA to resume with Sections 4–5b. Everything *else* is yours; escalating rote work back to the parent defeats the dispatch as surely as never dispatching.
- **Don't run `gh pr merge` yourself**, even when you're sure you'd be allowed. Denied twice from subagents on `mcp-obsidian-cli`, never once from a main session; the attempt costs a round trip and buys nothing (Section 0a).
- **You may dispatch your own subagent** when the repo's policy names a reviewer (Section 2.0 rung 3). Fan-out is recursive; a review agent under you is expected, not overreach.
- **Escalate the release merge.** Open the release PR, watch its checks, report it ready by number, and stop there (Section 6).
- The launching prompt should include PR number(s) and repo path. If it doesn't, ask the dispatcher (don't guess).
- You *may* rebase and `--force-with-lease` a feature branch to clear a conflict (Section 2d) — it's reversible and the branch is yours. Never force-push a protected branch.
- If you hit *any* unfamiliar conflict pattern, stop and report rather than guess. The cost of escalating is low; the cost of a bad merge is not.
- Surface conflict-resolution decisions you made (e.g. "merged the audit-test UNSKIPPED set") in the report so the parent and user can verify before the merge lands.
- Reports (one message each, at readiness and after cleanup): PRs merged with SHAs, issues labeled, conflicts resolved and how, how the review gate resolved (docs-only, CI check, review agent run, or waived), and whether anything came back blocked by the classifier (quoted verbatim if so — the dispatch brief in Section 0 asks for this explicitly). It is the only thing the user sees of this run, so make it scannable and complete. If you stopped short, lead with what blocked you. Leave promotion out unless they asked for it.

**If the run stops before the merge** — a failed check you can't attribute to flake, an unfamiliar conflict, or the Section 2.0 review gate unsatisfied — log it per Section 5b with `--outcome stopped`, then report and stop. Those are the judgment calls worth waking the user for, and a background dispatch surfaces them the same way it surfaces success.

## Safety

- Never merge a PR with failing checks (after one re-run attempt for clearly unrelated flake)
- Resolve the Section 2.0 review gate on its own ladder before merging code. Docs-only skips it, a CI check decides it, a repo whose policy names a reviewer gets that reviewer. Merge over unaddressed findings only when the user waived them
- Promote to prod only on an explicit keyword in the user's own invocation, and never offer promotion they didn't ask for
- Never write authorization language into a subagent prompt (Section 0). State facts the parent will act on; irreversible steps stay with the parent
- `gh pr merge` runs in the main session, every target branch, every time (Section 0) — a subagent's merge call is denied by the classifier, and no rewording fixes it
- When the auto-mode classifier blocks an action, change the shape of the approach or hand it to the user (Section 0a). Never route around a denial with a different tool to accomplish the same denied action
- Never force-merge or bypass review requirements (`--admin`)
- Always delete the local branch after merge to prevent stale-branch work
- Always switch to the base branch after cleanup — never leave the user on a deleted branch
- When creating release PRs, wait for checks before merging to the release branch
- Never force push to the release branch (`main`/`master`). `--force-with-lease` is acceptable on feature branches during rebase-on-conflict (Section 2d) but never on protected branches.
- Never delete `dev`, the release branch (`main`/`master`), or any branch the repo treats as permanent
- Background agents must not auto-promote to prod without explicit keyword authorization (Section 6)
- **Do NOT refresh or commit a knowledge graph (graphify) here.** Graph refresh happens at PR-create (commit skill, Section 6) so it rides the PR and becomes permanent at merge. Committing a regenerated graph directly onto `dev`/`master` post-merge would violate the no-direct-commit rule — the graph is already current in the base branch from each feature PR.
