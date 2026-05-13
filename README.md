# stonematt-skills

Cross-surface Claude Code / Codex / opencode / claude.ai skills authored by Matt Stone.

Pairs with a private `stonematt-skills` dotfiles stow package for persona content.

## Install

### Claude Code (and Codex / opencode)

```bash
npx skills@latest add stonematt/stonematt-skills
```

Or as a Claude Code plugin:

```
/plugin marketplace add stonematt/stonematt-skills
/plugin install stonematt-skills
```

### Claude Desktop / web / mobile

Skills run on claude.ai via uploaded zip bundles. Build a bundle locally and upload it via Settings → Features → Skills:

```bash
./scripts/build-claudeai-zip.sh voice lithos
# → produces stonematt-voice-lithos.zip
```

The bundle includes the skill plus selected persona files. Persona files must be on your local machine (see [Personas](#personas)).

## Skills

**engineering/** — [commit](./skills/engineering/commit/SKILL.md), [merge](./skills/engineering/merge/SKILL.md), [promote-settings](./skills/engineering/promote-settings/SKILL.md), [sync-plugin-manifest](./skills/engineering/sync-plugin-manifest/SKILL.md)

**productivity/** — [ai-sniff-test](./skills/productivity/ai-sniff-test/SKILL.md), [client-report](./skills/productivity/client-report/SKILL.md), [continue-after-clear](./skills/productivity/continue-after-clear/SKILL.md), [journal](./skills/productivity/journal/SKILL.md), [journal-status](./skills/productivity/journal-status/SKILL.md)

Planned (not yet migrated):

- **productivity/** — `email` (generic), `voice` (generic)

The `email` and `voice` skills will be **generic** — they take a persona slug as an argument and resolve persona content from a configurable path. See [`docs/adr/0001-cross-surface-persona-architecture.md`](./docs/adr/0001-cross-surface-persona-architecture.md).

## Personas

This repo contains **zero** identity content. Personas (voice fingerprints, email signatures, brand guidelines) live in a private dotfiles stow package — they are not published here.

Bootstrap a persona on your machine:

```bash
./bin/persona-init <slug>
# scaffolds $XDG_CONFIG_HOME/stonematt-skills/persona/<slug>/{voice,email}.md
# plus Tier 2 shim skills in the dotfiles stow source
```

## Repository conventions

- See [`CLAUDE.md`](./CLAUDE.md) for agent skill configuration (issue tracker, triage labels, domain docs)
- See [`CONTEXT.md`](./CONTEXT.md) for the project's vocabulary
- See [`docs/adr/`](./docs/adr/) for architectural decisions

## License

MIT — see [`LICENSE`](./LICENSE).
