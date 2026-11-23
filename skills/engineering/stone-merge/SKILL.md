---
name: stone-merge
description: Merge a pull request, clean up its branch, label its issues, and promote to the release branch when asked. Use when the user asks to merge or land a PR, to merge once checks are green, or to merge and release.
---

# Merge

The user ran this skill so they can stop thinking about the merge. Unless something is wrong, they hear about it once, when it lands.

This file is for the **dispatcher**: the session the user is typing in. The **agent** that performs the merge works from [`AGENT.md`](AGENT.md). If a brief dispatched you here, you are the agent: read `AGENT.md` in this skill's base directory now and work from it alone. The rest of this file is the dispatcher's.

A normal run costs the dispatcher two tool calls: this skill load and one `Agent` dispatch.

## 1. Dispatch

One `Agent` call:

- `subagent_type: "general-purpose"`, `model: "sonnet"`, `run_in_background: true`
- `description: "Merge PR #<num> into <base>"`. The description says plainly that the agent merges.
- A brief that carries **facts only**:
  - the repo path (a subagent does not inherit your `cwd`)
  - the PR number(s), or "the open PR for branch `<branch>`" when the user gave none
  - the base branch, if you know it
  - `Dispatching session: <name>`, this session's name as `ListAgents` reports it
  - the user's invocation, quoted verbatim: `The user's invocation was: "merge this"`. The agent reads the review waiver and the promotion keyword from the quoted words itself, so pass the words and not your reading of them.
  - the gates, stated as constraints: `Merge only after the skill's review gate resolves (docs-only skip, a passing code-review CI check, or the repo's recorded reviewer) and every check is green; a red check, an unresolved gate, or an unrecognised conflict stops the run before the merge.`
  - the directive: `Load this merge skill with the Skill tool (the same skill name you loaded it by — normally "stone-merge"), then execute it as the agent: its AGENT.md, every step that applies, including gh pr merge. Report back once, in the shape the Report step describes.` Name the skill exactly as you invoked it. If the agent has no Skill tool, give the absolute path of `AGENT.md` instead.

Then write one line and end your turn: "Merging PR #N in the background; you'll get one report when it lands or stops."

## 2. Relay

Your reply is the agent's report, blocker first. The agent has already verified the merge and the cleanup, so the relay needs no tool call of yours. If your dispatch was denied as transient and passed on the retry, add one line that quotes the denial.

Three reports ask something of you. Section 3 covers each; every other report is finished work.

## 3. Hand-backs

### The review policy question

The agent stopped because the repo has no recorded review policy, and its report carries one question. Relay it. When the user answers, spend at most three calls:

1. Write `project_review_policy.md` into this project's memory directory, body `review: <value>`.
2. Append its index line to `MEMORY.md` there with one shell `printf >>`.
3. Dispatch a **fresh** agent with the same brief plus the line `Recorded review policy: review: <value>`.

If the user declines to set a policy, dispatch the fresh agent with `Recorded review policy: review: optional (this run only)` and write nothing.

### CI unavailable

Relay what the agent saw and ask the user once whether to bypass CI for this PR. Run `gh pr merge --admin` only when all three hold:

1. The user approves the bypass in their own words, for this PR. An earlier or standing approval covers no other PR.
2. The repo's local gates pass on the PR's head commit: the commands CI runs, as the repo's `CLAUDE.md` names them. A repo that names none has no bypass; the merge waits for CI.
3. A PR comment, posted before the merge, records why CI is unavailable, the head SHA tested, and each local command with its result (pass counts, or the tail of the output).

Then merge with the command the agent reported plus `--admin`, and resume the agent with `SendMessage` carrying the merge SHA and the comment URL. A release PR takes the same path; its local gates run on `dev`'s head. This hand-back is the only use of `--admin`.

### A denied release merge

The agent's `gh pr merge` on the release PR was denied, and its report carries the exact command. The user asked for the release in their own words and the release PR is green, so run that one command, then resume the same agent with `SendMessage` carrying the merge SHA. Relay its final report with the denial quoted.

## When the dispatch is denied

Read the denial text.

- **Transient**: the text says `Stage 2 classifier error … (usually transient -- retrying often succeeds)`. Retry the identical call once.
- **Content**: any other denial, for example `Reason: [Merge Without Review]`. The run ends there. Try the log row once (`<skill-dir>/log-run.sh --pr <N> --outcome blocked --merged-from none --classifier "<verbatim>"`), then report: the denial verbatim, that nothing was merged, and the two ways to finish. The user can say "merge this" again later, because denials are intermittent, or run `!gh pr merge <N> --merge --delete-branch --subject "…"` themselves.

A denial is data for the report. The merge stays with the agent or the user: a denied dispatch is never a reason to run the workflow inline or to re-cut the brief so that the merge lands in this session.

## Running inline

Run inline only when this session has no `Agent` tool, or the user asked you to stay in this context. Read `AGENT.md` and follow it as both dispatcher and agent, logging `--merged-from main`.
