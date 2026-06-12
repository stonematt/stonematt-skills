# stonematt-skills

Public repo for portable Claude Code / Codex / opencode / claude.ai skills authored by Matt Stone.

## Language

**Skill**:
A self-contained capability with a `SKILL.md` (frontmatter `name`, `description`) + supporting files. Activates via the description string in any agent that reads SKILL.md files.
_Avoid_: command, plugin (different concept in Claude Code)

**Bucket**:
Top-level taxonomy folder under `skills/`. One of: `engineering/`, `productivity/`, `misc/`, `personal/`, `in-progress/`, `deprecated/`. Mirrors the mattpocock convention.
_Avoid_: category, group, namespace (reserve "namespace" for the `stone-` prefix)

**Namespace**:
The `stone-` prefix carried by every shipped skill's directory name, `name:` frontmatter, and slash command. Guarantees collision-free installs in the flat, name-keyed Central store. Only the explicit `/name` carries it — natural-language triggers (the `description`) activate unprefixed.
_Avoid_: scope, vendor-prefix

**Central store**:
`~/.agents/skills/` — the flat directory the `skills` CLI installs into, keyed by bare skill name (tracked in `~/.agents/.skill-lock.json`) and symlinked into each agent's skills dir. Flat name-keying is why the Namespace exists.
_Avoid_: registry, cache

**Surface**:
A platform a skill runs on. Three relevant surfaces: **Claude Code** (filesystem, hooks), **claude.ai** (web/desktop/mobile — no CLI or filesystem; skills upload as zip Bundles via Settings → Customize → Skills), **Codex/opencode** (filesystem-similar to CC).

**Bundle (claude.ai)**:
A zip containing one skill's folder at the zip root. Built by `scripts/build-claudeai-zip.sh <skill>`; uploaded by hand via claude.ai Settings → Customize → Skills.

## Relationships

- A **Skill** lives in exactly one **Bucket**.
- Every shipped **Skill**'s directory, `name:`, and slash command share the `stone-` **Namespace**.
- A **Skill** installs into the **Central store** by its namespaced name and is symlinked into each filesystem **Surface**; claude.ai is the exception — it takes an uploaded **Bundle**.

## Example dialogue

> **Matt:** "Why is my commit skill called `stone-commit`?"
> **Agent:** "**Namespace.** The `skills` CLI installs into a flat **Central store** keyed by bare name, so a generic `commit` would clobber another pack's. The `stone-` prefix is collision-proof — you still trigger it by saying 'commit this'; only `/stone-commit` carries the prefix."
> **Matt:** "And on the desktop app?"
> **Agent:** "Different **Surface**. claude.ai has no filesystem — build a **Bundle** with `build-claudeai-zip.sh stone-commit` and upload it via Settings → Customize → Skills."

## Flagged ambiguities

- "skill" was used to mean both a directory in this repo AND a thing installed in `~/.agents/skills/` (symlinked into each agent). Resolved: a **Skill** is the directory containing `SKILL.md`; "installed skill" is the entry in the **Central store**.

## Scope (locked)

- **In:** 7 `stone-*` skills authored by Matt Stone — `stone-commit`, `stone-merge`, `stone-promote-settings` (engineering); `stone-ai-sniff-test`, `stone-client-report` (productivity); `stone-journal`, `stone-journal-status` (personal).
- **Deferred** (parked on `feat/voice-personas`): the generic `voice` / `email` / `define-voice` skills, `bin/persona-init`, persona-bundling in the zip builder, and ADR-0001 (cross-surface persona architecture). Re-integrate as one unit later.
- **Out:** `continue-after-clear`, `sync-plugin-manifest` (removed — unused). The Claude plugin path (`.claude-plugin/` — superseded by the `skills` CLI). Identity skills `lithos-voice` / `lithos-email` (private dotfiles). Third-party copies (`web-design-guidelines`, `marp-slides`, `excalidraw-diagram`, `mermaid-visualizer`, `obsidian-canvas-creator`, `ux-designer-skill`, `graphify`). Hooks, agents, settings, CLAUDE.md (separate concerns).
