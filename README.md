# stonematt-skills

Cross-surface Claude Code / Codex / opencode / claude.ai skills authored by Matt Stone.

All skills are namespaced `stone-*` so they install into a shared central store
(`~/.agents/skills`) without colliding with same-named skills from other packs.
The prefix only changes the explicit slash command (`/stone-commit`) — natural-language
triggers ("commit this", "write a journal") are unaffected.

## Install

### Claude Code / Codex / opencode (and most filesystem agents)

```bash
npx skills@latest add stonematt/stonematt-skills
```

Pick the skills and agents in the interactive prompt. The CLI copies them into
`~/.agents/skills` and symlinks them into each agent. Re-run to update.

**Developing this repo?** Live-symlink the working copy into `~/.claude/skills` instead:

```bash
./scripts/link-skills.sh
```

### Claude Desktop / web / mobile

claude.ai has no CLI or filesystem install — upload a zip by hand via
**Settings → Customize → Skills**. Build one per skill:

```bash
./scripts/build-claudeai-zip.sh stone-commit   # → stone-commit.zip
```

## Skills

**engineering/** — [stone-commit](./skills/engineering/stone-commit/SKILL.md), [stone-merge](./skills/engineering/stone-merge/SKILL.md), [stone-promote-settings](./skills/engineering/stone-promote-settings/SKILL.md)

**productivity/** — [stone-ai-sniff-test](./skills/productivity/stone-ai-sniff-test/SKILL.md), [stone-client-report](./skills/productivity/stone-client-report/SKILL.md), [stone-journal](./skills/productivity/stone-journal/SKILL.md), [stone-journal-status](./skills/productivity/stone-journal-status/SKILL.md)

The generic persona skills (`voice`, `email`, `define-voice`) and their tooling are
parked on the `feat/voice-personas` branch for future re-integration.

## Repository conventions

- See [`CLAUDE.md`](./CLAUDE.md) for agent skill configuration (issue tracker, triage labels, domain docs)
- See [`CONTEXT.md`](./CONTEXT.md) for the project's vocabulary
- See [`docs/adr/`](./docs/adr/) for architectural decisions

## License

MIT — see [`LICENSE`](./LICENSE).
