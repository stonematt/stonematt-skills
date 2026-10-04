---
name: bse-monitor
description: Watch a repo for BSE issues that become ready for an agent, and land each one through a fresh subagent, all the way to merge.
disable-model-invocation: true
---

A **ready BSE** is an open issue labelled `bse` and `ready-for-agent`, with no `owner: build` label. If the user's arguments name other labels, use those. The repo is the current checkout's GitHub repo unless the user names one.

The watch runs until the user stops it. Each ready BSE gets its own subagent in its own worktree, so several BSEs, and several watching sessions, can be in flight at once. The main session holds only claims, merge calls and short reports. Invoking this skill authorizes every merge it makes; the user is not asked again.

## 0. Refresh the dispatch notes

The **dispatch notes** are a memory note named `bse-monitor` in the project's auto-memory directory. Read it. When it is missing, or its `checked` date is earlier than today, refresh it:

- **implement:** find `implement/SKILL.md` under the project's `.claude/skills/`, else `~/.claude/skills/`. Record its path and the first 12 characters of its `shasum -a 256`. When neither exists, record `fallback`; dispatches then follow [`DISPATCH-FALLBACK.md`](DISPATCH-FALLBACK.md).
- **integration branch:** the base that PRs target (the GitHub default branch unless the repo's docs name another).
- **gates:** every check command the repo defines, from its agent docs, profile or `package.json` scripts.
- **lifecycle doc:** the repo's doc for merge method, merge subject and cleanup, or `none`.
- **labels:** the three label names in use.

Write the note with this body under the memory frontmatter (`type: reference`), and add its one-line pointer to `MEMORY.md` on first write:

```markdown
## Dispatch notes
checked: <YYYY-MM-DD>
implement: <path> (sha256 <12 chars>) | fallback
integration branch: <branch>
gates: <command>; <command>; …
lifecycle doc: <path> | none
labels: <bse>, <ready-for-agent>, <owner: build>
```

When the implement hash differs from the previous note, tell the user the implement skill changed since the last check.

**Done when** the note's `checked` date is today and every field holds a value.

## 1. Arm the watch

Start a `Monitor` with `timeout_ms: 1800000` (the cap) and the description `new ready BSEs on <owner/repo>`:

```bash
repo=<owner/repo>
skip=" "
while true; do
  nums=$(gh issue list --repo "$repo" --label bse --label ready-for-agent --state open \
    --json number,labels \
    --jq '.[] | select([.labels[].name] | index("owner: build") | not) | .number' 2>/dev/null || true)
  for n in $nums; do
    case "$skip" in *" $n "*) ;; *) echo "new ready BSE #$n"; skip="$skip$n " ;; esac
  done
  sleep 300
done
```

The first poll reports every BSE that is ready now. That backlog is your first batch.

**Done when** the Monitor is running and you have told the user which repo it watches and which recipe its agents follow: the implement skill's path, or the fallback.

## 2. Handle each event

An event can name several issues. Take each one through these steps in order.

**a. Read the brief.** Read the issue body and every comment. Skip the issue if the brief says it is blocked, if it needs a path the repo freezes for agents, or if it needs a device, a credential or a human eye. A skipped issue goes on the skip list (step 3). Tell the user why, with the issue URL, and send a `PushNotification`, because a skip waits on them.

**b. Claim it, race-checked.** Other sessions claim BSEs at the same time. Re-read the labels immediately before you claim. If `owner: build` is there, another session holds the issue; skip it without a notification. Otherwise add the label, then confirm that your edit is the one that made the claim:

```bash
gh api --paginate repos/<owner/repo>/issues/<n>/timeline --jq '.[] | select(.event=="labeled" and .label.name=="owner: build") | .created_at' | tail -1
```

The timestamp must be less than a minute old. An older one means another session claimed the issue first and your label edit changed nothing. Skip the issue and leave the label in place.

**c. Dispatch one fresh subagent.** Use `model: sonnet` and `isolation: "worktree"`. The brief carries the issue URL, the dispatch notes, and this task:
1. Create a descriptive task branch for the issue from the tip of the integration branch.
2. Follow the recipe. For an implement path, read that `SKILL.md` and follow it, with every skill it points at. It sets `disable-model-invocation`, so the `Skill` tool cannot load it; read the file. For `fallback`, read `DISPATCH-FALLBACK.md` and follow it; the brief gives its absolute path, because the subagent cannot see this skill's folder.
3. Run every gate in the dispatch notes and fix what fails.
4. Push the branch, open a PR into the integration branch, and report the PR number, the reviewed head SHA, the gate results and any screenshots.

The merge stays out of the brief: `gh pr merge` is allowed only from the main session.

**d. Merge from the main session.** Judge any screenshots. Then run `stone-merge`, following the lifecycle doc for the merge method, the subject line, the cleanup and the audit comment, and merge as soon as readiness passes. When a screenshot shows a defect, or a review finding or a check blocks readiness, resume the same subagent with `SendMessage` to fix it. After two rounds that still leave the PR blocked, put the issue on the skip list, comment the blocker on the PR, and send a `PushNotification`.

**Done when** every issue in the event is merged with its cleanup verified, or is on the skip list with its reason given to the user.

## 3. Re-arm on expiry

The Monitor stops after 30 minutes. Re-arm it with the same script, setting `skip` to every number you skipped, space-separated with a leading and a trailing space (`skip=" 278 403 "`). Claimed and merged issues need no entry, because the query already filters them out. On the first re-arm after midnight, run step 0 again.

**Done when** a new Monitor is running with the current skip list. When the user says stop, end the Monitor with `TaskStop`.
