# Pull request

The pull request branch of [`stone-commit`](SKILL.md). `<base>` is the branch the user named; otherwise `dev` where the repo has one, else the default branch.

## Steps

### 1. Sync onto the base

```bash
git fetch origin
git rev-list --count HEAD..origin/<base>
```

A count of 0 means the base has not moved: go to step 2. Otherwise bring the base in without rewriting anything already on the remote:

- **Branch not pushed yet** (`git rev-parse --verify -q origin/<branch>` fails) → `git rebase origin/<base>`.
- **Branch already pushed** → `git merge origin/<base>`, so the next push is a plain fast-forward.

Resolve a conflict only when it has one of these shapes:

- **List-add**: both sides added entries to the same list, set, dict or import block → keep both, in the file's ordering.
- **Counter-bump**: both sides bumped the same number → take the higher.

Any other conflict is a logic conflict: copy the conflicted hunk, undo the attempt (`git rebase --abort` or `git merge --abort`) so the tree is clean, then stop and report the file and hunk.

Done when the count is 0 and the branch is on the remote: `git push -u origin HEAD`. A PR request is a request to push.

### 2. Link the issues

One branch can ship several tickets. Collect every match from these sources, then union and dedupe:

- **Tickets named this session** as the branch's work ("implement #31 and #32"). Authoritative.
- **Commit messages**: `git log origin/<base>..HEAD --grep '#[0-9]\+'` for refs and `Closes #N` / `Refs #N` trailers.
- **Branch name**: `^[a-z]+/(\d+)[-/_]` or `^issue[-/_](\d+)`. Legacy branches only; a miss is expected.
- **A brief named in the commits** (`docs/briefs/<slug>.md`): `gh issue list --search "<slug>" --state open`.

Keep an issue only when it is open (`gh issue view <N> --json state`) and has no open sub-issues. A parent or spec issue closes when its children do, not from a PR.

An empty set on a branch that looks like tracked work gets one question: "No ticket refs found, so this PR will close nothing. Ticket number(s)?"

Done when every source is checked and every kept issue is confirmed open.

### 3. Refresh the knowledge graph (repos that track it)

A committed graph rides the PR. The block is a no-op where the graph is untracked or graphify is absent. It gates on tracked-ness because `graphify-out/` exists locally in every graphify project and `git add` on an ignored path is an error.

```bash
if git ls-files --error-unmatch graphify-out/graph.json >/dev/null 2>&1 \
   && command -v graphify >/dev/null 2>&1; then
  env -u ANTHROPIC_API_KEY graphify update .
  git add graphify-out/graph.json graphify-out/GRAPH_REPORT.md
  if ! git diff --cached --quiet; then
    git commit -m "chore: refresh knowledge graph"
    git push
  fi
fi
```

### 4. Create the PR

Write the title and body from the whole branch: its commits (`git log --oneline origin/<base>..HEAD`) and its diff (`git diff origin/<base>...HEAD`). A one-commit branch takes that commit's title. Pass the body on stdin:

```bash
gh pr create --base <base> --title "<title>" --body-file - <<'EOF'
Closes #31
Closes #32

## Summary
- <bullet>

## Test plan
- [ ] <checklist item>

## Merge Danger
- **Door:** one-way | two-way — <optional one-line note>
- **Blast radius:** <one word> — <optional: what could break>
EOF
```

- **`Closes #N`**: one line for each linked issue, above `## Summary`; no block when nothing is linked. Write them on PRs into `dev` too. GitHub only closes on a merge to the default branch, but `stone-merge` reads these lines to label each issue `status: staged`, and the release PR reuses them.
- **Door**: `two-way` when reverting the merge fully undoes its effect, else `one-way`. Always `one-way`, with the path named in the note, when the diff adds or changes a database migration, changes what gets published (a package manifest's `version`, `files`, `bin` or `exports`, or a release workflow), changes infrastructure-as-code, or deletes tracked data.
- **Blast radius**: `none`, `local`, `module`, `app-wide`, `consumers` or `data`.
- Merge Danger informs the reader. It gates nothing.
- The body ends at Merge Danger: no "Generated with" footer, no session link.
