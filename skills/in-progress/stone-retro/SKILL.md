---
name: stone-retro
description: Run the upstream retro skill with the house sources and the house filing rules.
disable-model-invocation: true
---

# Retro, filed

The upstream `retro` skill does the analysis. This skill adds two sources to what it reads and says where its candidates are filed. The categories, the ranking and the judgement are upstream's: follow its file as written and take nothing about them from here.

## Steps

### 1. Read the upstream skill

Read `~/.claude/skills/retro/SKILL.md` in full, on every run; it changes upstream. Where that path is absent, read `~/.agents/skills/retro/SKILL.md`. `retro` is user-invoked, so the Skill tool cannot load it: the file read is the way in.

Neither file exists → stop and say that the `retro` skill is not installed. A retro written from memory of that skill is not a substitute.

### 2. Add the house sources

Upstream's step 2 names the primary sources. Read these with them:

- **Earlier retros**: `~/.claude/skill-workbench/retro/notes.md`.
- **The merge run log**, when a session under review merged a PR or the user asked for a deep retro: `~/.claude/skills/stone-merge/log-summary.sh --since <date of the earliest session under review>`. Its rows are evidence across sessions, which no single transcript shows.

### 3. Run the upstream steps

Follow the upstream file from its first step to its last. When a candidate matches a finding already in `notes.md`, say so in its line: `repeat of <date> #<n>`.

### 4. File the candidates

After presenting them, append one dated section to `~/.claude/skill-workbench/retro/notes.md`, in the shape of the sections already there:

- a heading: `## <date> — <repo>, <session name> (<session id>)`
- a `Session:` line saying what the session did
- the candidates, numbered, each with its finding in bold, its upstream category, the evidence, a `Fix:` and a `Home:`

A candidate whose home is a skill also goes into that skill's `~/.claude/skill-workbench/<skill>/feedback.md`, as a dated entry: what happened, the run or PR it came from, and the line of the skill it would change. Create the file with a `# <skill> feedback` title where it is missing. A candidate that cannot name the line stays in `notes.md` alone.

Done when every candidate presented is in `notes.md` with a `Home:`, and you have told the user which ones repeat an earlier retro.
