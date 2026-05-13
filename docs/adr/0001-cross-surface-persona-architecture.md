# Cross-surface persona architecture

stonematt-skills must run on three surfaces (Claude Code, claude.ai web/desktop/mobile, Codex/opencode) and serve at least three real personas (Lithos consulting, NWHub board comms, StoneGynOnc brand) while keeping persona content out of the public repo. We adopt: **public generic skills (`voice`, `email`) that resolve a persona via a documented chain — env var → XDG config → bundled-in-skill-dir → relative — plus private Tier 2 shims in dotfiles that declare persona-named triggers and delegate to the generic skill**. claude.ai gets a `build-claudeai-zip.sh` script that copies selected `persona/<slug>/` content into a zip alongside the generic skill so the resolver finds it under `$SKILL_DIR/persona/...` after upload.

This is mildly novel: published prior art (mattpocock, anthropic/skills, voice-replication, voice-editor, humanizer-skill, brand-guidelines) all either bake identity into the skill OR resolve a single profile file from inside the repo. None published the cross-surface resolver pattern. The trade-off accepted: more moving parts (generic skill + private persona file + optional shim + claude.ai zip builder) versus the simpler "one full skill per persona, duplicate per surface" alternative. We chose the resolver because (a) the user has three personas today and intends to package the pattern for consulting clients, (b) the shim delegation keeps Tier 1 as single source of truth, (c) the public repo carries zero persona names or fingerprints.

## Consequences

- Generic skill bodies must implement the resolver chain explicitly (4 paths, first-hit wins). Tests should cover the chain.
- Tier 2 shims are optional — if a user only runs Tier 1, `/voice lithos` works without any shim installed. Shims exist for natural-language ergonomics and backward compatibility with the user's prior `/lithos-voice` muscle memory.
- claude.ai workflow is asymmetric: every persona change requires a re-zip + re-upload. Acceptable because persona files change rarely.
- `bin/persona-init <slug>` must write to two locations: `$XDG_CONFIG_HOME/stonematt-skills/persona/<slug>/` (templates) AND the dotfiles stow source for the shim (`<dotfiles>/stonematt-skills/dot-claude/skills/<slug>-voice/`, etc.). It needs the dotfiles path — read from `STONEMATT_DOTFILES_DIR` env or prompt.
- `ai-sniff-test` wired as auto-gate in `voice` and `email` for long-form output. Opt-out via `--skip-sniff`. Skipped for slack-style short messages.
