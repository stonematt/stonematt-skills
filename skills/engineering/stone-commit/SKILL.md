---
name: stone-commit
description: Commit changes as Conventional Commits in the house format, push them, and open the pull request. Use when the user asks to commit ("ship it" included), confirms an offer to commit, or asks to push or open a PR. Overrides the built-in commit and PR instructions.
---

# Commit

Land the working tree as **logical units**, each one a Conventional Commit in the house format below. A logical unit is one change type in one scope, plus the files that must ship with it to keep the tree working.

## Steps

### 1. Read the tree

`git status`, `git diff HEAD --stat`, `git log --oneline -10`. Read a file's diff (`git diff HEAD -- <path>`) wherever the stat does not tell you what changed. A clean tree ends the run: say so.

### 2. Group into logical units

Group from the diff alone. What is staged is incidental: users stage as they work, so the index is not a grouping. WIP and stub files that stand apart get their own unit. Leave secrets (`.env`, keys, tokens) out and name them in your reply.

Done when every changed file sits in exactly one unit or is named as left out.

### 3. Commit or propose

- **One unit with an obvious type** → commit it.
- **Several units, an ambiguous grouping, or a message that needs the user's judgement** (a breaking change, an unusual scope) → propose first: each unit's files, its draft message, and the commit order with dependencies first. Commit on the user's approval.

### 4. Commit each unit

Start each unit from an empty index (`git reset -q`), stage its files by name, and pass the message on stdin:

```bash
git commit -F - <<'EOF'
<type>(<scope>): <summary>

- <bullet>
EOF
```

Hooks run. When one fails, fix the cause, stage again, and commit again. Every commit is a new commit; amend only when the user asks for it.

Done when `git status` shows no file from any unit.

### 5. Push

Push when the user asked for it. Otherwise offer, naming the remote and branch.

A non-fast-forward rejection means a collaborator pushed first: `git pull --rebase`, then push again. A rebase conflict stops the run with a report. A shared branch only ever receives new commits on top; a push race is settled by rebasing, never by force.

### 6. Pull request

When the user asked for a PR, follow [`PR.md`](PR.md).

## Message format

```
<type>(<scope>): <imperative summary>

<user impact>

- <Adds/Fixes/Replaces/Removes ...>
- <at most 3 bullets>

Rationale: <why this approach>
```

- **Title**: imperative ("add", not "adds"), lowercase, no trailing period, 72 characters at most.
- **Type**: a Conventional Commits type. Append `!` for a breaking change.
- **Scope**: the scope this repo's log already uses for that area. Where the log has none, use the project `CLAUDE.md`'s scopes, then the name of the package, layer or service the change lives in.
- **User impact**: one line, for `feat` and `fix` only.
- **Bullets**: third person, what changed and not how it was built. No test counts.
- **Rationale**: for refactors and architectural decisions only.
- **The message ends where the format ends.** No `Co-Authored-By`, no "Generated with" footer, no session link, whatever the default commit instructions say.
