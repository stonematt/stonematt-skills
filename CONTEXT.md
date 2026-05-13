# stonematt-skills

Public repo for portable Claude Code / Codex / opencode / claude.ai skills authored by Matt Stone. Pairs with a private dotfiles stow package (`stonematt-skills`) that holds identity-bearing persona content.

## Language

**Skill**:
A self-contained capability with a `SKILL.md` (frontmatter `name`, `description`) + supporting files. Activates via the description string in any agent that reads SKILL.md files.
_Avoid_: command, plugin (different concept in Claude Code)

**Bucket**:
Top-level taxonomy folder under `skills/`. One of: `engineering/`, `productivity/`, `misc/`, `personal/`, `in-progress/`, `deprecated/`. Mirrors the mattpocock convention.
_Avoid_: category, group, namespace

**Persona**:
A named identity (e.g. `lithos`, `nwhub`, `stonegyne`) that supplies voice and channel-specific content to generic skills at runtime. Identified by a slug.
_Avoid_: voice, brand, profile (each names a part, not the whole)

**Channel**:
A communication format keyed off a persona — `voice.md`, `email.md`, `slack.md`, `board-memo.md`. Each persona may carry multiple channels.
_Avoid_: medium, mode

**Generic skill**:
A public, identity-free skill (e.g. `voice`, `email`) that takes a persona slug as `$ARGUMENTS` and resolves the persona file at runtime. Lives in this repo.
_Avoid_: parameterized skill (too jargon-y)

**Shim**:
A thin private skill in the dotfiles `stonematt-skills` package (e.g. `lithos-voice/SKILL.md`) whose only job is to provide persona-specific natural-language triggers and delegate to a generic skill. Body is small; identity is in the persona file, not the shim.
_Avoid_: wrapper, alias

**Tier 1 / Tier 2**:
**Tier 1** = public generic skills shipped in this repo. **Tier 2** = private shims shipped in dotfiles. Tier 2 is optional — users can always invoke Tier 1 explicitly with a persona arg.

**Resolver**:
The persona-lookup chain inside a generic skill body. Tries (in order): `$STONEMATT_SKILLS_CONFIG/persona/<slug>/<channel>.md` → `$XDG_CONFIG_HOME/stonematt-skills/persona/<slug>/<channel>.md` → `$SKILL_DIR/persona/<slug>/<channel>.md` (claude.ai bundle case) → `./persona/<slug>/<channel>.md`. First hit wins.
_Avoid_: lookup, search path

**Surface**:
A platform a skill runs on. Three relevant surfaces: **Claude Code** (filesystem, hooks), **claude.ai** (web/desktop/mobile — skills upload as zip bundles, FS only inside the bundle), **Codex/opencode** (filesystem-similar to CC).

**Bundle (claude.ai)**:
A zip containing `SKILL.md` plus selected `persona/<slug>/` content. Built by `scripts/build-claudeai-zip.sh`. Uploaded via claude.ai Settings → Features → Skills.

**Persona init**:
Bootstrap script `bin/persona-init <slug>` that scaffolds a new persona: creates `$CFG/persona/<slug>/{voice,email}.md` templates AND writes the matching Tier 2 shim into the dotfiles tree. Run once per persona.

## Relationships

- A **Skill** lives in exactly one **Bucket**.
- A **Generic skill** (Tier 1, public) resolves a **Persona** at runtime via the **Resolver**.
- A **Shim** (Tier 2, private) targets one **Persona** + one **Channel** and delegates to one **Generic skill**.
- A **Persona** has zero or more **Channels** under `$CFG/persona/<slug>/`.
- A **Bundle** packages one **Skill** + one or more **Personas** for one **Surface** (claude.ai).
- **Persona init** writes both a **Persona** scaffold AND its **Shims** in a single run.

## Example dialogue

> **Matt:** "I want to draft a board memo as NWHub voice."
> **Agent:** "I'll trigger the **Shim** `nwhub-voice`, which delegates to the **Generic skill** `voice` with persona=nwhub. The **Resolver** loads `$CFG/persona/nwhub/voice.md`. Output runs through `ai-sniff-test` as a quality gate."
> **Matt:** "Now do the same on the web client."
> **Agent:** "Different **Surface**. The **Shim** doesn't ship there — claude.ai only sees what's in the uploaded **Bundle**. Run `scripts/build-claudeai-zip.sh nwhub voice`, upload the resulting zip, then invoke the generic `voice` skill with persona=nwhub. The persona file is read from `$SKILL_DIR/persona/nwhub/voice.md` inside the bundle."

## Flagged ambiguities

- "voice" was overloaded — used to mean both the **Generic skill** named `voice` AND a **Channel** named `voice.md`. Resolved: the **Generic skill** is the executable; the **Channel** is the file the skill reads. Same word, two concepts, both kept because both are well-established.
- "skill" was used to mean both a directory in this repo AND a thing installed in `~/.claude/skills/`. Resolved: a **Skill** is the directory containing `SKILL.md`; "installed skill" is the symlink/copy at the target location.

## Scope (locked)

- **In:** 11 skills authored by Matt Stone — `ai-sniff-test`, `client-report`, `commit`, `continue-after-clear`, `email` (generic), `journal`, `journal-status`, `merge`, `promote-settings`, `sync-plugin-manifest`, `voice` (generic).
- **Out:** lithos-email and lithos-voice in their current form (decomposed into `email` + `voice` generic + private shims). Third-party copies (`web-design-guidelines`, `marp-slides`, `excalidraw-diagram`, `mermaid-visualizer`, `obsidian-canvas-creator`, `ux-designer-skill`, `graphify`). Workspace dirs (`*-workspace`). Hooks, agents, settings, CLAUDE.md (separate concerns; settings would risk leaking host IDs).
