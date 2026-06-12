---
name: stone-journal-status
description: Show a summary of dev journal entries. Trigger when user says /stone-journal-status, "journal status", "show journal", "journal entries", "what's in the journal", "list journal", or asks about journal contents. Use this instead of /stone-journal when the user wants to review existing entries rather than create new ones.
---

# Journal Status

Show a table of all journal entries with date, theme, and metadata.

## Workflow

### 1. Verify journal worktree

Check that `.journal/` exists via `git worktree list`. If missing, tell the user to run `/stone-journal` first to set it up.

### 2. Read entries

List all files in `.journal/docs/journal/*.md` sorted by name (chronological).

For each file, extract from YAML frontmatter and first heading:
- `date` — from frontmatter
- `generated` — from frontmatter (last written/updated timestamp)
- `commits` — from frontmatter
- `branch` — from frontmatter
- **theme** — from the first `## YYYY-MM-DD - ` heading, take everything after the dash

### 3. Display

Present as a table, most recent first:

```
## Journal Entries

{count} entries from {earliest date} to {latest date}

| Date | Commits | Generated | Theme |
|------|---------|-----------|-------|
| 2026-04-02 | 75 | Apr 2, 20:45 | Phase 08.4 founder polish, full cycle |
| 2026-03-31 | 12 | Mar 31, 23:10 | ... |
| 2026-03-30 | 26 | Mar 30, 23:50 | ... |
```

Format the `generated` column as short datetime (Mon DD, HH:MM) for scannability.

If the user asks about a specific entry (e.g., "what did I do on March 30"), read and display that entry's full content.
