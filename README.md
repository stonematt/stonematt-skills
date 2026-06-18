# stonematt-skills

Cross-surface Claude Code / Codex / opencode / claude.ai skills authored by Matt Stone.

All skills are namespaced `stone-*` so they install into a shared central store
(`~/.agents/skills`) without colliding with same-named skills from other packs.
The prefix only changes the explicit slash command (`/stone-commit`) — natural-language
triggers ("commit this", "write a journal") are unaffected.

## Install

Pick your path by the app you run. There are two mechanisms: a **filesystem
install** (one command, covers every coding agent) and a **manual zip upload**
(for the claude.ai chat app, which has no filesystem).

> **Two different "desktop apps" — don't conflate them.** The **Claude Code
> desktop app** (Anthropic's coding tool, Mac/Windows) is a *filesystem* agent —
> use the npx path. The **claude.ai desktop app** (the chat app, same as the
> iOS/Android app) has *no* filesystem — use the zip path.

| Your app | Path |
|----------|------|
| Claude Code — terminal CLI | npx, or the plugin marketplace |
| Claude Code — desktop app (Mac/Win) | plugin marketplace (no terminal), or npx — shares `~/.claude/skills` with the CLI |
| Codex / opencode | npx (filesystem) |
| claude.ai — desktop app / web / mobile | zip upload |

### Filesystem agents — Claude Code (CLI or desktop app), Codex, opencode

```bash
npx skills@latest add stonematt/stonematt-skills
```

Pick the skills and agents in the interactive prompt. The CLI copies them into
`~/.agents/skills` and symlinks them into each agent. Re-run to update.

The **Claude Code desktop app** reads the same user-scope `~/.claude/skills/` as
the terminal CLI, so a single install on a machine serves both. If a skill
doesn't appear in the desktop app after installing, restart it (or re-run the
command) so it re-scans the skills directory.

**Developing this repo?** Live-symlink the working copy into `~/.claude/skills` instead:

```bash
./scripts/link-skills.sh
```

This links the working-copy skills into both `~/.claude/skills` and
`~/.agents/skills` for Claude Code and Codex dogfooding.

### Claude Code — plugin marketplace (no terminal needed)

Claude Code (CLI or desktop app) can install the whole pack as a plugin straight
from this repo — handy if you'd rather not run `npx` in a terminal:

```
/plugin marketplace add stonematt/stonematt-skills
/plugin install stonematt-skills@stonematt-skills
```

Skills load namespaced as `/stonematt-skills:stone-commit` (natural-language
triggers like "commit this" are unchanged). Claude Code only — Codex and opencode
have no plugin system, so use the npx path above for those.

### claude.ai chat app — desktop, web, mobile

claude.ai (the chat app — **not** the Claude Code desktop app above) has no CLI
or filesystem install. Upload a zip by hand via **Settings → Customize →
Skills**. Uploaded skills are tied to your claude.ai account, so one upload is
available wherever you're signed in (web, desktop, mobile). This path is
best-effort for the MVP until bundle compatibility is validated against the
current uploader. Build one per skill:

```bash
./scripts/build-claudeai-zip.sh stone-commit   # → stone-commit.zip
```

## Skills

**engineering/** — [stone-commit](./skills/engineering/stone-commit/SKILL.md), [stone-merge](./skills/engineering/stone-merge/SKILL.md), [stone-promote-settings](./skills/engineering/stone-promote-settings/SKILL.md)

**productivity/** — [stone-ai-sniff-test](./skills/productivity/stone-ai-sniff-test/SKILL.md), [stone-client-report](./skills/productivity/stone-client-report/SKILL.md)

**personal/** — [stone-journal](./skills/personal/stone-journal/SKILL.md), [stone-journal-status](./skills/personal/stone-journal-status/SKILL.md)

The generic persona skills (`voice`, `email`, `define-voice`) and their tooling are
parked on the `feat/voice-personas` branch for future re-integration.

## Repository conventions

- See [`CLAUDE.md`](./CLAUDE.md) for agent skill configuration (issue tracker, triage labels, domain docs)
- See [`CONTEXT.md`](./CONTEXT.md) for the project's vocabulary
- See [`docs/adr/`](./docs/adr/) for architectural decisions

## Test

Run the lightweight pre-merge gate before merging to `main`:

```bash
./scripts/test.sh
```

This validates skill naming/index consistency and the claude.ai zip smoke test.

## License

MIT — see [`LICENSE`](./LICENSE).
