# Session brief template

One brief per dispatched session. The session starts cold: the brief is all it knows. Write facts the release manager has checked, not instructions to go and find them.

Fill each section. Cut a section only when it does not apply (a read-only review has no rollback).

```markdown
You are <the job, in one line: what and for which release>. Repo: <path>. You start in the <project>-ops worktree, detached at origin/<branch> = <sha>. <Make your own worktree or branch for code. | Read-only: do not edit, commit or push.>

Matt's words: "<his exact words that started this thread>". <What he was answering, in one line.>

Read <the runbook, e.g. docs/agents/operations.md> first, and <the issue, PR section or comment that defines the job, with links>.

Known state (facts):
- <what is deployed where, at which SHA>
- <hosts, the exact ssh form, the backups that exist>
- <what other sessions already did, and the lines that must stay unchanged>
- <earlier failures to avoid, and why>

Steps:
1. <Back up before you change anything: name the backup path.>
2. <One action, then how to check it.>
3. <Only if step 2 passes, the next one.>
4. <Tick the done boxes on <issue>, and post a short comment.>

<For a review: the seats or areas, the bar ("blocker = <what stops the release>"), and the tags blocker / fix / note.>

Leave for Matt, and list each as an exact step in your report: <the dashboard steps and the denied commands, with the SHA each needs>.

Hard rules: <the systems this session must not write to>. Never print secret values. <If production answers 5xx after the change, roll back with <command>, then stop and report.> Merge no PR. If an action is denied, stop that action and report it; do not route around it. No AI attribution in any commit, PR or comment.

Report back once with SendMessage to "<project> · <manager session name>": <the facts the manager needs to check your claims: links, SHAs, check results, diffs, what is left>. Keep it under <8–12> lines.
```

## Why each part is there

- **Start point and SHA.** Two sessions on one checkout collide. The ops worktree is detached, so each session makes its own branch.
- **Matt's words.** The session acts on his intent. Quote it; do not turn it into a permission ("prod is authorized"). A brief that grants authority for an irreversible act can be denied at dispatch (`~/.claude/CLAUDE.md`, "Model Routing").
- **Known state.** The manager already holds these facts. A session that finds them again spends time, and can find a different answer.
- **Backup first, then check each step.** The ops sessions that worked backed up before they changed anything and checked each step before the next.
- **Rollback.** A step that changes production names its exact rollback, so the session does not improvise one under a 5xx.
- **A bar for reviews.** "Blocker = <what stops the release>" keeps a panel from holding the release on polish.
- **Merge no PR.** Merges are the manager's call (SKILL.md step 5).
- **The report address.** `<project> · <name>` as `ListAgents` prints it. The bare name fails.
- **A short report.** One report, with the links and SHAs the manager needs to check it cheaply.
