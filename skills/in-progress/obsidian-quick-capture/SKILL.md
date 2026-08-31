---
name: obsidian-quick-capture
description: Capture a quick note into the Obsidian vault inbox (0.inbox/) in a single CLI call — no template, minimal handrolled frontmatter, lightweight first-mention [[wikilinks]] in the body, works from any project. Use when the user wants to save, capture, jot, drop, or stash a note, idea, snippet, link, or short runbook to Obsidian, or says "quick capture", "save to vault", "capture to obsidian", "note this in obsidian", "drop this in my inbox", "stash this in obsidian". The vault's inbox-processor applies full schema and placement later.
---

# Obsidian Quick Capture

Drop a note into the vault inbox as **one `obsidian create` call**. No template — `templater:create-from-template` forces a multi-step frontmatter→body→cleanup dance that is wasted on a capture. Handrolled minimal frontmatter is the sanctioned exception to "always use templates", scoped to `0.inbox/` only. Downstream `inbox-processor` applies the real fileClass schema and PARA placement.

## Quick start

```bash
# 1. Get a literal timestamp (never inline $(date) in the arg)
date "+%Y-%m-%dT%H:%M"     # → 2026-06-10T09:14

# 2. One call. Substitute the literal timestamp, slug, and body.
obsidian vault="tyee" create silent path="0.inbox/<descriptive-slug>.md" content="---\nCreated: 2026-06-10T09:14\nstatus: inbox\ntags:\n  - capture\n---\n\n<body with first-mention [[wikilinks]]>\n"
```

Output: `Created: 0.inbox/<descriptive-slug>.md`. Done — confirm the path back to the user.

## Rules

- **`path=` not `name=`** — `name=` rejects `/`, so it cannot target a folder.
- **Slug**: kebab-case, descriptive. No parens in filenames (`Name - Context`, not `Name (Context)`).
- **`\n` renders as real newlines** in `content=`. Plain prose, apostrophes, and `code spans` pass clean — no escaping needed.
- **Timestamp literal**: run `date` first, interpolate the value. Never embed `$(date)` in the arg.
- **Default vault `tyee`** (primary PKM). Set `vault=` for another (e.g. `scarp`).
- **Skip the `Skill obsidian:obsidian-cli` load** — this command is pre-verified; you are not discovering verbs, so it cannot silently fail.

## First-mention wikilinks

Wrap the **first mention** of each salient entity in the body in `[[wikilinks]]` (Kepano / Karpathy first-mention style) — people, orgs, projects, tools, distinctive concepts worth a future note. First mention only; leave later mentions as plain text.

- **Lightweight, no validation.** Do not query vault vocab or check whether the target note exists. Ghost links (to notes not yet created) are expected and fine — they are the wiki graph's frontier.
- **Be sparing.** A handful per note. Skip generic words; link what you'd plausibly want a backlink to later.
- `[[Name]]`, or `[[Name|display text]]` to keep prose natural.
- Best-guess the title (e.g. `[[Andrej Karpathy]]`, `[[open-design MCP]]`); don't research or disambiguate.

For heavier, vault-vocabulary-aware annotation (transcripts, dedup against existing notes), use the `annotate-wikilinks` skill instead — quick-capture stays dependency-free and never queries the vault.

## Frontmatter

Minimal required: `Created`, `status: inbox`. `tags` list optional. Add `source:` when capturing from another project so origin is traceable. Keep it minimal — inbox-processor enriches to the real schema.

```yaml
---
Created: 2026-06-10T09:14
status: inbox
tags:
  - capture
source: dev/vaults/scarp        # optional — origin repo/url
---
```

## Edge case — code-block-heavy body

Multi-line `content=` with fenced code blocks (backslashes, line continuations) is where inline escaping breaks: doubled `\\`, mangled quotes. For runbooks / code-heavy notes, capture a short summary + link here, then build the full note vault-side with the heavier `create` → `append` → `app.vault.process` flow. Do not force a code-heavy body through `content=`.

## Downstream

Captured notes carry `status: inbox`. Run the vault project's `inbox-processor` skill to file them — it applies fileClass frontmatter, wikilinks, and PARA placement.
