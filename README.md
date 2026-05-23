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

**productivity/** — [ai-sniff-test](./skills/productivity/ai-sniff-test/SKILL.md), [client-report](./skills/productivity/client-report/SKILL.md), [continue-after-clear](./skills/productivity/continue-after-clear/SKILL.md), [define-voice](./skills/productivity/define-voice/SKILL.md), [email](./skills/productivity/email/SKILL.md), [journal](./skills/productivity/journal/SKILL.md), [journal-status](./skills/productivity/journal-status/SKILL.md), [voice](./skills/productivity/voice/SKILL.md)

`voice` and `email` are **generic** skills — they take a persona slug as an argument and resolve persona content from a configurable path. `email` resolves both the persona's `email.md` (signature/contact) and `voice.md` (tone). `define-voice` is the authoring counterpart — it writes (or amends) the `voice.md` that `voice` and `email` read. See [`docs/adr/0001-cross-surface-persona-architecture.md`](./docs/adr/0001-cross-surface-persona-architecture.md).

## Usage

The generic `voice` skill applies a persona's voice to drafted prose, or reviews prose against it. Persona content is private (see [Personas](#personas)); the skill is identity-free.

**Tier 1 — invoke explicitly with a persona slug:**

```
/voice --persona nwhub draft a board update about the Q3 budget
/voice --persona nwhub --skip-sniff quick reply: confirm Tuesday works
```

The Resolver finds the persona's `voice.md` via: `$STONEMATT_SKILLS_CONFIG` → `$XDG_CONFIG_HOME/stonematt-skills` → the skill's bundle dir → `./persona`. First hit wins. Long-form output runs through `ai-sniff-test` unless `--skip-sniff` is passed.

Omit `--persona` to fall back to `$STONEMATT_DEFAULT_PERSONA` (export your most-used slug so `/voice` just works). The skill only asks when both the flag and the env var are unset.

The `email` skill works the same way, resolving the persona's `email.md` (signature/contact) on top of its `voice.md` (tone):

```
/email --persona lithos reply to Dan declining the Tuesday call, propose async
/email --persona lithos --register cold intro to a prospective client
```

**Tier 2 — invoke a persona-named shim** (optional, lives in private dotfiles):

```
/nwhub-voice draft a board update about the Q3 budget
write this as nwhub
```

A shim just pre-binds `--persona nwhub` and delegates to `voice`. Tier 1 works without any shim installed.

**Author or amend a voice:**

```
/define-voice --persona nwhub          # interview + write nwhub's voice.md (or amend it if it exists)
/define-voice --persona nwhub --from ~/samples.md   # infer the voice from existing writing
```

`define-voice` writes to the **private** persona path (`$STONEMATT_SKILLS_CONFIG` → `$XDG_CONFIG_HOME/stonematt-skills`), never into this repo. It produces the hybrid shape (core one-liner + style rules + numeric targets + few-shot pairs + anti-patterns) that `voice` reads.

**Scaffold a new persona** (empty templates + Tier 2 shim, for the dotfiles stow flow):

```bash
export STONEMATT_DOTFILES_DIR=/path/to/dotfiles
./bin/persona-init nwhub          # writes a voice.md template + nwhub-voice shim into the dotfiles stow source
./bin/persona-init nwhub --dry-run # preview without writing
# then: stow -d "$STONEMATT_DOTFILES_DIR" stonematt-skills
```

`persona-init` scaffolds the empty template + shim; `define-voice` fills in (or later edits) the actual voice content.

**Build a claude.ai bundle:**

```bash
./scripts/build-claudeai-zip.sh voice nwhub   # → stonematt-voice-nwhub.zip
```

Upload via claude.ai Settings → Features → Skills. The persona file ships inside the zip so the Resolver finds it under the bundle dir.

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
