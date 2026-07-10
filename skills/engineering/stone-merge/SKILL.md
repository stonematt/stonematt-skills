---
name: stone-merge
description: Merge a pull request, clean up the branch, and optionally promote to production. Use this skill whenever the user wants to merge a PR — including /stone-merge, "merge it", "merge the PR", "land it", "merge and release", "merge to prod", "ship to production", or any confirmation after checks pass. Also trigger when the user says "merge after checks", "merge when green", or refers to merging + deploying in the same breath. This is the counterpart to /stone-commit — commit gets code ready, merge lands it and cleans up.
---

# Merge Skill

The post-commit counterpart to `/stone-commit`. Handles the full lifecycle after code is ready: wait for checks, merge the PR, clean up the branch, and optionally promote to production.

The work is procedural — gated waits on `gh pr checks --watch`, retry loops, branch bookkeeping. None of it benefits from Opus reasoning, and watching checks in the foreground parks the main session on bookkeeping. Delegate to a sonnet subagent by default. See Section 0.

## 0. Delegate to a sonnet subagent (foreground default)

If you are the main agent **and** the Agent tool is available **and** the user did not say "stay" / "do it here", your first action when this skill is invoked is to dispatch the work to a sonnet subagent and return. Don't run Sections 1–7 yourself.

**Why this matters.** A typical `/stone-merge` waits 1–10 minutes on CI checks via `gh pr checks --watch`. Holding that in the main Opus context burns tokens against a long-lived prompt cache and blocks the user from steering you on something else. A sonnet subagent has no such cost — it returns one summary message at the end.

**How to dispatch.** Call the Agent tool with:

- `subagent_type: "general-purpose"`
- `model: "sonnet"`
- `description: "Merge PR #<num>"` (or "Merge and release PR #<num>" if prod authorized)
- `prompt`: a self-contained brief that the subagent can act on without your conversation history. Include:
  - The PR number(s) and base branch
  - Repo path (the subagent doesn't inherit `cwd` context the way you might assume)
  - Whether prod promotion is authorized — quote the user's exact words if ambiguous (Section 6 keywords)
  - Whether the code-review gate (Section 2.0) is waived — pass `--no-review` scope only if the user explicitly said so; otherwise the subagent enforces the gate and stops to ask
  - The directive to follow this skill: `"Load the merge skill at ~/.claude/skills/stone-merge/SKILL.md and execute Sections 1–7. Skip Section 0 since you are the subagent."`
  - What to report back: PRs merged with SHAs, issues labeled, conflicts resolved (with how), prod status (promoted or "did not promote, prompt did not authorize")

**When NOT to delegate.**
- You are already a subagent (no further delegation — execute the sections yourself).
- The user explicitly said "do it here" / "stay in this context" / "merge yourself".
- Agent tool is unavailable in the current harness.
- The PR is so trivial and fast (e.g. checks already green at invocation) that the round-trip overhead exceeds the win — judgment call.

**Foreground vs background.** Default to foreground (you wait for the subagent's summary, then relay to user). Use `run_in_background: true` only if the user has clearly given you other work to do in parallel — otherwise foreground keeps the conversation linear.

After dispatch, surface the subagent's summary to the user verbatim or condensed. Don't re-execute its work.

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

Before probing mergeability, confirm a code review ran on this branch. Never merge substantive product code that was never reviewed. Two detection modes:

**CI-check mode (preferred).** If the repo runs `/code-review` as a GitHub Action — a check whose name matches `code.?review` — require it:

```bash
gh pr checks <number> --json name,state --jq '.[] | select(.name|test("(?i)code.?review")) | "\(.name) \(.state)"'
```

- `SUCCESS` → gate passes, continue to the readiness checks below.
- `PENDING`/`IN_PROGRESS`/`QUEUED` → the watch loop (2a) will cover it; note it and proceed.
- `FAILURE` → treat like any failed check (2b): read the review output, do **not** merge over unaddressed findings.
- No matching check returned → fall to local mode.

**Local mode (no CI review check).** Git history can't reliably prove a local `/code-review` run happened, so confirm rather than guess:

> "No code-review CI check on this PR. Has `/code-review` run on this branch since the last commit? (already did / run it now / skip — trivial docs-only)"

Block until the user confirms review ran or explicitly waives it. When you ARE a subagent, surface this to the dispatcher — never self-waive.

**Bypass.** `/stone-merge --no-review` (or the user saying "skip review") waives the gate for trivial docs/infra PRs. Record the waiver in the final report.

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
3. For each issue: `gh issue edit <N> --repo <owner/repo> --add-label "status: staged" --remove-label "status: wip"`.
4. Skip silently if no references found — many PRs (docs, infra) won't have any.

When the release PR (dev→release branch) merges later, GitHub auto-closes via closing keywords and the `clean-status-on-close.yml` workflow strips the label. **But this only works if the release PR body uses `Closes #N` / `Fixes #N` / `Resolves #N` for every staged issue.** Section 6 step 5 has a defensive sweep for the case where keywords are missing or the workflow isn't installed.

### 6. Production promotion (gated)

**Default: do NOT auto-promote.** Production deploys are high-stakes shared-system changes. Per safe-action norms, modifying production needs explicit user authorization for *this specific action* — generic "auto mode" or background-agent invocation is not enough.

Auto-promote only if the original prompt explicitly contains one of: `prod`, `production`, `release`, `ship to prod`, `merge and release`, or the user said "merge and release" / "to main" / "to master" in plain language. If the prompt is just "merge", "merge it", "land it", or a PR number alone, **stop after Section 5** and offer:

> "PR merged to `<base>`. Want me to create a release PR to `<release>`?"

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

6. Confirm: "Merged to `<release>`. Production deploy rolling out at `<vercel/wherever URL if visible>`. Stripped `status: staged` from N issues."

**Never force push to `<release>`. Never use `--admin` on a release PR. Never delete `dev` or `<release>`.**

### 7. Update project state (if GSD is active)

If `.planning/STATE.md` exists, update it to reflect the merge:
- Set "Last activity" to today's date
- If the merged branch was for a specific phase, update "Phase" and "Status" fields
- Clear any stale plan references from the status line context

This prevents the GSD status line from showing a stale branch/plan name after merge.

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

Section 0 dispatches the work to a sonnet subagent by default. When you ARE that subagent (or any background agent running this skill), the conversation is short and the user isn't watching every tool call. Tighten the loop accordingly:

- The launching prompt should already include PR number(s), repo path, and explicit prod-promotion scope. If it doesn't, ask the dispatcher (don't guess).
- Refuse prod promotion unless the prompt contains the keywords listed in Section 6, even if the PR base is `dev`.
- Surface conflict-resolution decisions you made (e.g. "merged the audit-test UNSKIPPED set") in the final report so the dispatcher and user can verify.
- If you hit *any* unfamiliar conflict pattern, stop and report rather than guess. The cost of escalating is low; the cost of a bad merge is not.
- Final report (one message, returned to dispatcher): PRs merged with SHAs, issues labeled, conflicts resolved (with how), production status (or "did not promote, prompt did not authorize"). Keep it scannable — the dispatcher will relay it to the user.

## Safety

- Never merge a PR with failing checks (after one re-run attempt for clearly unrelated flake)
- Never merge substantive product code past the Section 2.0 code-review gate unless it passed or was explicitly waived (`--no-review`); subagents surface the gate, never self-waive
- Never force-merge or bypass review requirements (`--admin`)
- Always delete the local branch after merge to prevent stale-branch work
- Always switch to the base branch after cleanup — never leave the user on a deleted branch
- When creating release PRs, wait for checks before merging to the release branch
- Never force push to the release branch (`main`/`master`). `--force-with-lease` is acceptable on feature branches during rebase-on-conflict (Section 2d) but never on protected branches.
- Never delete `dev`, the release branch (`main`/`master`), or any branch the repo treats as permanent
- Background agents must not auto-promote to prod without explicit keyword authorization (Section 6)
- **Do NOT refresh or commit a knowledge graph (graphify) here.** Graph refresh happens at PR-create (commit skill, Section 6) so it rides the PR and becomes permanent at merge. Committing a regenerated graph directly onto `dev`/`master` post-merge would violate the no-direct-commit rule — the graph is already current in the base branch from each feature PR.
