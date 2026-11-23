# Promotion to the release branch

The promotion branch of [`AGENT.md`](AGENT.md), reached only when the user's invocation asked for a release. `dev` and the release branch are permanent: they are never deleted and only ever receive merges.

## Steps

### 1. Find the release branch and the range

```bash
RELEASE=$(git show-ref --verify --quiet refs/remotes/origin/main && echo main || echo master)
git log origin/$RELEASE..origin/dev --oneline
```

### 2. Version the release

Applies when the repo versions its releases: a `version` in its manifest, a `CHANGELOG.md`, or `vX.Y.Z` tags. A release is done when its tag exists and names what is deployed.

- **Next version**, from the Conventional Commits in step 1's range, including branch commits under merge commits: `!` or `BREAKING CHANGE` → major, any `feat` → minor, otherwise patch. A `Release-As: X.Y.Z` footer wins.
- Cut `release/vX.Y.Z` from `origin/dev`, commit the version bump and the new CHANGELOG section there (`chore(release): vX.Y.Z`), and push. That branch is the release PR's head in step 3, so one merge carries the code and its version.
- After step 4's merge: `gh release create vX.Y.Z --target <merge-sha> --title vX.Y.Z --notes-file <the CHANGELOG section>`. Step 5 brings the release back into `dev`; then delete `release/vX.Y.Z`.

**Repos on release-please:**

- Pointed at `dev` (`target-branch: dev`, `skip-github-release: true`): the release-please PR into `dev` replaces the `release/vX.Y.Z` branch. Merge it into `dev` last, then open the release PR from `dev`. A job on the release branch tags the manifest's version at the release PR's head and relabels the version PR `autorelease: tagged`. Reference: `stonematt/bike_race_results`, `.github/workflows/release-please.yml` and `scripts/tag-release.ts`.
- Still targeting the release branch: merge its version PR right after the release PR. Merged first, it cuts off the commits the release PR brings, and the tag and changelog skip them.

### 3. Open the release PR

The body carries a `Closes #N` line for every issue staged by the promoted commits: `gh issue list --label "status: staged" --json number`.

```bash
gh pr create --base <release> --head <dev or release/vX.Y.Z> --title "<title>" --body-file - <<'EOF'
## Summary
- <bullets summarising the promoted commits>

Closes #N
Closes #M

## One-way doors
- #<pr> — <note>
EOF
```

`## One-way doors` gets one bullet for each promoted PR whose body has `**Door:** one-way`, carrying its note. Leave the heading out when there are none. It informs the reader and gates nothing.

### 4. Merge the release PR

`AGENT.md` step 3 applies to the release PR: watch, one flake rerun, green only. Then merge it and keep its head branch:

```bash
gh pr merge <release-pr> --merge --subject "Merge dev: <title> (#<release-pr>)"
```

**If this merge is denied**, stop before step 5 and say so plainly in the report: "release merge denied in the agent; the command is: …". The dispatcher runs that one command and resumes you with the merge SHA. On that message run steps 5 to 9, with `--merged-from main` in step 8. With no resume, steps 5 to 9 stay undone, and your report already says so.

### 5. Bring the release back into `dev`

Merge the release branch's tip into `dev`, not the release PR's head branch (`release/vX.Y.Z`). The release merge commit exists only on `<release>`; merging its tip carries that commit into `dev`, so `<release>` is never ahead of `dev`. The PR's head is a throwaway branch at that tip, never `<release>` itself: a repo that deletes head branches on merge would delete the release branch.

```bash
git fetch origin
git push origin origin/<release>:refs/heads/back-merge/<vX.Y.Z or the release date>
gh pr create --base dev --head back-merge/<...> --title "chore(release): bring <vX.Y.Z or the release title> back to dev" --body "Back-merge of #<release-pr>."
gh pr merge <back-merge-pr> --merge --delete-branch --subject "Merge back-merge/<...>: chore(release): bring <vX.Y.Z or the release title> back to dev (#<back-merge-pr>)"
```

`AGENT.md` step 3 applies: watch, one flake rerun, green only. A denied merge takes step 4's path.

**Done when** `git fetch origin && git rev-list --count origin/dev..origin/<release>` prints 0.

### 6. Return to `dev`

`git checkout dev && git pull`.

### 7. Sweep the staged labels

`gh issue list --repo <owner/repo> --state all --label "status: staged" --json number --jq '.[].number'`. For each issue whose PR is now in the release branch (`gh pr list --search "<N> in:body is:merged base:<release>"`): `gh issue edit <N> --remove-label "status: staged"`. An issue whose PR has not shipped keeps its label.

### 8. Log the promotion

Its own row: `--pr <release-pr> --base <release> --outcome merged --sha <sha> --checks pass --classifier none --merged-from subagent --note promotion`.

### 9. Report

Add to the `AGENT.md` report: "Merged to `<release>` (`<sha>`), back-merged into `dev` (`<sha>`). Stripped `status: staged` from N issues."
