---
name: stone-journal
description: Generate a dev journal entry for today's work — pulling signal from git commits AND the non-git context that matters in 6 months (vendor integrations, stack decisions, infra events, service signups, dead-ends worth remembering). Trigger when the user says /stone-journal, "journal entry", "write up today's work", "log today", or similar. Trigger even when the day had no commits but real work happened (accounts created, services configured, DNS changed, architectural decisions made).
---

# Journal Entry Skill

## Workflow

### 1. Ensure the journal worktree exists

Journal entries live on an orphan `journal` branch in a `.journal` worktree at the repo root. This keeps bookkeeping out of feature branches and mainline history.

**First-run setup** (if `.journal/` doesn't exist):

Run `scripts/journal-setup.sh` from the skill directory. It creates the orphan branch and attaches the worktree. If the script isn't available, do it manually — each step as a separate bash call to avoid compound command permission issues:

1. `git switch --orphan journal` (creates orphan branch, no shared history)
2. `git commit --allow-empty -m "init: journal branch"`
3. `git switch -` (back to previous branch)
4. `git worktree add .journal journal`

Then ensure `.journal` is in `.gitignore` on the current working branch (not the journal branch). Check first, append only if missing.

**Subsequent runs:** Verify `.journal/` exists (`git worktree list`). If missing (e.g., after a fresh clone), re-attach: `git worktree add .journal journal`.

### 2. Determine the date range

Run in parallel:

- `ls .journal/docs/journal/*.md 2>/dev/null | sort | tail -1` (most recent entry)
- `git branch --show-current` (active branch in main worktree)
- `git diff --stat HEAD` (uncommitted changes in main worktree)
- `hostname -s` (for frontmatter)

**Determine the start date:**
- If journal entries exist, read the `date:` frontmatter of the most recent file. The range starts from that date (inclusive — the existing entry gets upserted with any new commits).
- If no entries exist, use `git log --reverse --format=%ad --date=short | head -1` to find the first commit, then ask the user how far back to go.
- If the user specifies a date or range (e.g., "journal for last week"), use that instead.

Then fetch commits for the full range:
- `git log --since="<start-date>" --all --format="%H %ad %s" --date=short`
- `git log --since="<start-date>" --all --stat`

**Why author date:** Author date reflects when the work was done, not when it was rebased or merged. A `--no-ff` merge on Thursday of work done Monday-Wednesday correctly attributes the commits to Mon/Tue/Wed.

**Group commits by author date.** Each unique date with commits becomes one journal entry.

**Don't silently skip commit-less days.** A day without commits may still have had real work — an account signup, a DNS edit, a big decision made in conversation. The enrichment step (§2.5) surfaces these. Create a journal entry for any date where §2.5 finds material signal, even with zero commits.

### 2.5. Enrich context beyond git

Git only captures code changes. The work that future-you most needs to recognize — which vendor did we pick for email, when did we set up that account, why did we drop the SMS bridge, what was the region we chose, which approach did we abandon — usually happens in conversation, dashboards, and external services. Losing those means the journal becomes a partial record that drifts away from reality after a few months.

For each date in the range, gather non-git signal from three places. Then feed this enrichment into the synthesis step (§3) alongside the commit data.

**Source 1 — Claude Code transcripts** (`~/.claude/projects/<project-slug>/*.jsonl`)

Claude Code stores each project's transcripts under `~/.claude/projects/<slug>`, where `<slug>` is the absolute repo path with separators mapped to `-`. **Do not hand-build the slug** — the exact mapping has changed across Claude Code versions (`.` was once preserved, e.g. `…-github.com-…`, and is now replaced, e.g. `…-github-com-…`), so one repo's history can be split across two slug dirs. Resolve robustly instead: normalize both the cwd and every dir name under `~/.claude/projects/` to a canonical form (all non-alphanumerics → `-`) and keep the dirs whose canonical form matches the cwd's, unioning signal across them. The bundled helper (below) does exactly this; prefer it over manual slug construction. Transcripts are JSONL with `timestamp`, `role` (user/assistant), and `content`. Filter by timestamp into the date range; skip `tool_result` blocks (file reads / command output flood the keyword filter with false positives).

From the messages, pull content that matches any of these patterns:
- **Vendor / service events** — "created account", "signed up at X", "verified domain", "added API key", references to product names (Resend, Twilio, Stripe, Auth0, Supabase, Hover, Cloudflare, Vercel, etc.)
- **Stack decisions** — "let's use X", "drop Y", "switch from A to B", "we don't need Z", "going with N"
- **Out-of-band actions** — DNS records added at a registrar, secrets set in a dashboard, domains verified, manual smoke tests of external services
- **Architectural discoveries** — "turns out adapter X emits to path Y", "API Z doesn't behave the way we assumed"
- **Abandoned approaches** — "tried X, didn't work because Y, went with Z instead" (include only when the dead-end informs future decisions; skip routine debug cycles)

**Source 2 — Curated memory** (`<matched-project-dir>/memory/`)

Memory files are user-curated project learnings. New or modified memory files on a date are often the most important thing that happened that day — a correction, a preference, a constraint the model now knows to respect. Use the same robustly-resolved project dir(s) as Source 1 (the bundled helper covers this):

```bash
# For each project dir whose canonical name matches the cwd (see Source 1):
find "$PROJ_DIR/memory" -name '*.md' \
  -newermt "$START" ! -newermt "$END_PLUS_1" 2>/dev/null
```

Read each matching file's frontmatter `name` + body; surface as `**Learned:**` bullets in the entry.

**Source 3 — Plan files** (`~/.claude/plans/*.md`)

Plans are date-stamped intents. Compare plan context vs shipped work — gaps reveal pivots and cut scope, both of which are journal-worthy.

```bash
find ~/.claude/plans -name '*.md' \
  -newermt "$START" ! -newermt "$END_PLUS_1" 2>/dev/null
```

**Redaction before any LLM pass**

Transcripts commonly contain API keys, tokens, and other secrets that users pasted. Before passing transcript content to a model for summarization, strip known patterns. A non-exhaustive starter list: `re_[A-Za-z0-9]+` (Resend), `sk-[A-Za-z0-9]+` (OpenAI-style), `ghp_[A-Za-z0-9]+` and `ghs_[A-Za-z0-9]+` (GitHub), `AIza[A-Za-z0-9_-]+` (Google), `xox[bp]-[A-Za-z0-9-]+` (Slack), `Bearer \S+`, hex strings of length ≥ 32.

**Bundled helper**

Run `scripts/journal-enrich.sh <start-date> <end-date>` from the repo root (main worktree, not `.journal`) to gather all three sources and print a consolidated, redacted digest suitable for feeding into the synthesis step. It resolves the project dir(s) from `pwd` using the canonical-normalization match described in Source 1 — works in any repo and unions across legacy/current slug encodings. Its header echoes the matched dirs so you can confirm resolution succeeded.

### 3. Synthesize entries

For each date with either commits or §2.5 enrichment signal, synthesize one entry. Review commits, diffs, branch context, and the enrichment digest together. Group by logical theme, not by commit.

The goal is to capture raw material for later synthesis (in Obsidian or similar). Don't over-polish — record what happened and why, not a narrative essay.

**The 6-month test**

Before including any bullet, ask: *will future-me reading this in six months recognize or care about this line?* Bias the entry toward durable content:

- **Keep**: vendor / service signups and migrations, stack decisions (including reversals), integration points (what talks to what, via what), architectural discoveries that shape future work, abandoned approaches with the reason-why, DNS / infra / account events
- **Drop**: individual debug sessions, typo fixes, style-only refactors, which files got touched when, time-of-day granularity, test-count deltas, PR review ping-pong

When in doubt, lean toward leaving it out — the journal's value is density, not completeness.

**Rules:**
- Lead with a short theme line — the day's goal, not the activity
- 2-3 sentence narrative max — what changed and why
- **Organize by SOW/customer intent** (e.g., "V1->V2 migration", "Question-oriented dashboards"), not by artifact type or commit order. Use unlabeled sections or one-liners for work that doesn't fit these buckets.
- **Always include a `Decisions & external events` bucket** when §2.5 surfaced any signal for the day. This is where vendor integrations, account signups, DNS changes, stack pivots, and abandoned-approach notes go. Even if a day had zero commits, a new vendor signup is worth a dedicated entry. Examples:
  - `Chose Resend for transactional email — verified example.com via a send.* subdomain; apex SPF merge with Google wasn't needed.`
  - `Dropped email-to-SMS bridge via AT&T gateway — delivery stuck queued, carrier filtering suspected. SMS alerting re-planned on Twilio when capacity returns.`
  - `Adapter @astrojs/cloudflare@13 emits dist/server/wrangler.json; root wrangler.jsonc is metadata-only, CI deploys via --config.`
- Bullets for discrete deliverables, one per logical unit of work
- Group related commits into single bullets
- Skip boilerplate (formatting, typos, merge commits) unless that was the day's work
- For **merge commits**: note "merged branch X" in the narrative if it adds context, but don't give the merge commit its own bullet
- Include file/model/dashboard names when they add clarity
- **Highlight material user-facing changes** so future summarization notices them
- **Out-of-band work** (video recording, manual testing, demos, etc.) deserves extra attention — not discoverable in git history
- Optimize for scanning: minimize whitespace, use bold inline headers
- No "today I worked on..." framing
- No commit hashes in the entry
- No "Next" section or carry-forward tasks

**Upsert behavior:** When regenerating an entry for a date that already has a file, read the existing entry first. Preserve any out-of-band notes or manual edits the user added — merge them into the new entry.

### 4. Write entries and commit

Write each day to `.journal/docs/journal/YYYY-MM-DD.md` with YAML frontmatter:

```markdown
---
date: 2026-03-07
generated: 2026-03-12T14:32:00
branch: feature-auth
host: m4MBPro
commits: 3
---

## 2026-03-07 - Short Theme

**Branch:** `feature-auth` (3 commits)

[2-3 sentence narrative of what the session was about and why]

**Decisions & external events**
- Vendor / service integrations — what was picked and why; include account-level details (identity used, region, plan tier)
- Stack changes, reversals, abandoned approaches with the reason-why
- DNS / infra / dashboard events that don't touch git

**[SOW/intent bucket]**
- Concrete deliverable or change (include filenames where useful)
- Group related work into single bullets

**[Another bucket]**
- ...

**[Out-of-band label] (out-of-band)** - description of work not tracked in git
- Detail items if needed

```

**Frontmatter fields:**
- `date`: The day the work covers (YYYY-MM-DD). May differ from today if journaling retroactively.
- `generated`: Current datetime (YYYY-MM-DDTHH:MM:SS, local time) — when this entry was created or last regenerated.
- `branch`: The active git branch in the main worktree at time of writing.
- `host`: Machine hostname (`hostname -s`).
- `commits`: Number of commits covered by this entry.

**Write directly — no approval step.** Upsert without asking. The `generated` field updates so downstream tools detect the refresh. This is safe because the skill preserves manual additions during upsert.

**Commit inside the worktree** using the bundled script. The /stone-commit skill can't operate in a worktree (it runs `git status`/`git diff` in the main working tree), so journal uses its own commit script that follows the same conventions (Conventional Commits, heredoc):

```bash
bash <skill-dir>/scripts/journal-commit.sh .journal "docs: add journal entries for YYYY-MM-DD through YYYY-MM-DD"
```

Use singular "entry" and one date if only one day. The script uses `git -C` to operate inside the worktree without changing directories.

If the user says "no commit" or "don't commit", just write the files.

### 5. Verify date coverage

After writing entries but before committing, verify that every distinct author date with commits has a corresponding journal file. Run:

```bash
git log --since="<start-date>" --all --format="%ad" --date=short | sort -u
```

Compare the output against the set of files you just wrote or updated. If any date with commits is missing an entry file, create the missing entry before proceeding. Include a **Coverage** line in the report (§6) showing dates covered vs dates expected.

### 6. Report

After writing, show a summary table of all entries with their status (created or updated) and theme line. No fenced code blocks of the full entries unless the user asks to see them.

```
Journal entries written to .journal/docs/journal/:

| Date | Status | Theme |
|------|--------|-------|
| 2026-03-20 | created | Phase 4 planning |
| 2026-03-21 | created | Tree API implementation |
| 2026-03-22 | updated | SPA shell and shipping |

Committed as abc1234 on journal branch.
```

- **created**: new file, no prior entry for this date
- **updated**: existing entry was upserted (out-of-band notes preserved, commits merged)

## Style Guide

- **Tone:** Terse and scannable. Write for future-you skimming in 6 months. No emdashes, no "leveraging", no "streamlining", no filler adjectives. Use plain dashes (-) or rewrite the sentence.
- **Granularity:** One bullet per logical unit of work, not per commit or per file.
- **Indentation:** Use 4 spaces per indent level for nested bullets (Obsidian compatibility).
- **Names:** Use actual filenames, model names, dashboard names — not vague descriptions.
- **Theme line:** Scannable — captures the day's goal or focus area in ~5 words.
- **Narrative:** Brief context that wouldn't be obvious from the bullet list alone. Why this work, not just what.

## Safety

- Upsert is the default — existing entries are regenerated with new info merged in
- Preserve out-of-band notes and manual edits from existing entries during upsert
- If `.journal/docs/journal/` doesn't exist in the worktree, create it
- `--all` includes unmerged branch commits — intentional, you did the work even if it's not merged yet
- The `.journal` worktree must be in `.gitignore` on the main working branch
- Never commit journal entries to the current working branch — always use the worktree
