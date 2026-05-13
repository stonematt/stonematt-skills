---
name: continue-after-clear
description: Park the current session state to a memory file so work can be picked up cleanly after /clear. Use when the user says /continue-after-clear, /go-after-clear, "save state and clear", "park this session", "proceed after clear", "resume from checkpoint", "pick up where I left off", "where was I", or otherwise wants to bookmark and restore work across context resets. /continue-after-clear writes the file (run before /clear). /go-after-clear reads it (run in fresh session). Captures git branch, last commit, working-tree state, open PRs from the branch, the active task list, a one-line next action, and an exact resume prompt. Optional slug lets parallel threads be parked side by side.
---

# continue-after-clear / go-after-clear

Two verbs, one skill:

- **`/continue-after-clear <slug?>`** — write a state file. Run before `/clear`.
- **`/go-after-clear <slug?>`** — read a state file and re-orient. Run in fresh session after `/clear`. Also triggers on "proceed after clear", "pick up where I left off", "where was I", "resume from checkpoint".

Note: avoid `/continue` and `/resume` as read verbs — they collide with Claude Code built-ins.

Default slug is `current` (one slot, overwritten in place). Pass a slug to keep parallel parks: `/continue-after-clear hero-editorial`, `/continue-after-clear pr-72`.

## Where files live

Auto-memory dir for the active project:

```bash
bash ~/.claude/skills/continue-after-clear/scripts/memory-dir.sh
# -> ~/.claude/projects/<slug>/memory
```

Checkpoint files: `<memory-dir>/checkpoint_<slug>.md`. Index entry: `<memory-dir>/MEMORY.md`.

If `<memory-dir>` doesn't exist, create it. If `MEMORY.md` doesn't exist, create with `# <project> Memory` header.

## /continue-after-clear workflow

### 1. Resolve slug + paths

- Slug = first arg, else `current`. Lowercase, replace spaces with `-`.
- Memory dir from script above.
- Target file: `<memory-dir>/checkpoint_<slug>.md`.

### 2. Snapshot state

Run in parallel:

- `bash ~/.claude/skills/continue-after-clear/scripts/gather-state.sh` — git + gh PR snapshot
- **Call the `TaskList` tool yourself** to capture the active task list. The skill can't read it from disk — only the model has it. Include task statuses (in_progress, completed, pending).

### 3. Get "next action" + "resume prompt"

These two lines are the heart of the file. If the user already stated them, use them. Otherwise infer from the conversation and ask one short confirmation:

> Next action: `<one line>`
> Resume prompt: `<exact phrase to paste after /clear>`
> OK to write?

Keep both lines copy-pasteable. The resume prompt is what the user pastes into a fresh session — phrase it as instruction, not summary. Most common: `/go-after-clear` (or `/go-after-clear <slug>`).

### 4. Write the file

Frontmatter:

```yaml
---
name: <Title-case label>
description: <one-line state — branch, last activity, next task>
type: project
slug: <slug>
created: <ISO 8601 local, no timezone>
---
```

Body sections (use the headers verbatim — `/continue` parses them):

```markdown
## Where I left off — YYYY-MM-DD

**Branch:** `<branch>` (`<clean | N modified, M untracked | ahead/behind>`)
**Last commit:** `<sha> <subject>`

**Working tree:**
<paste `git status --short` output, or "clean">

**Open PRs from this branch:**
<paste from gh, or "(none)">

## Tasks

<paste TaskList snapshot — one line per task with status>

## Next action

<one line>

## Resume prompt

```
<exact phrase>
```

## Context

<2-4 sentences: what's in flight, gotchas, why the next action is the next action. This is what future-you reads first.>
```

### 5. Update MEMORY.md

Add or replace the pointer line under a `## Project State` section (create the section if missing):

```
- [Checkpoint: <slug>](checkpoint_<slug>.md) — <one-line description from frontmatter>
```

If a line for this slug already exists, replace it. Don't duplicate.

### 6. Print resume command

Last line of your reply is the literal command for the user:

```
/go-after-clear <slug>
```

(Or just `/go-after-clear` if slug is `current`. Plain text triggers like `proceed after clear` or `where was I` also work.)

## /go-after-clear workflow

### 1. Resolve slug + read file

- Slug = first arg, else `current`. If file missing, list what exists in `<memory-dir>/checkpoint_*.md` and stop.

### 2. Print one-paragraph state summary

Pull from frontmatter `description` + the **Context** section. Two sentences max. Include branch and next action explicitly.

### 3. List re-orient pointers

- Files / paths mentioned in **Working tree** or **Context** that are worth re-reading
- Open PRs from the file (numbers + titles)

### 4. Print suggested first command

The **Resume prompt** body, verbatim, in a code block.

### 5. Ask "continue or pivot?"

One line:

> Continue from this checkpoint, or pivot to something else?

Wait for the user's answer before doing work. Don't auto-execute the resume prompt.

## Constraints

- **TaskList must be captured by the model.** The skill can't snapshot tasks the model hasn't surfaced — call `TaskList` during `/continue-after-clear`, paste its output into the file. If skipped, write `(no tasks captured)` rather than fabricating.
- **No git mutations.** `/continue-after-clear` must not commit, push, stash, or branch. It only reads.
- **No /clear.** The skill writes the file and prints the resume command. The user invokes `/clear` themselves — Claude can't.
- **Slug collision = overwrite.** That's intentional for `current`. For named slugs, warn before overwriting if the existing file is < 1 hour old (probably accidental double-tap).
- **Cross-project safe.** Use `$CLAUDE_PROJECT_DIR` or `pwd` for the project root — never hardcode paths. The script handles slug derivation.

## Style

Keep these files dense. Future-you skim-reads them after `/clear` with no other context. Lead with the next action. Cut anything that isn't load-bearing for resuming work.
