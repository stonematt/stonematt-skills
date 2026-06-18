# stonematt-skills

Public repo for portable Claude Code / Codex / opencode / claude.ai skills authored by Matt Stone.

## Language

**Skill**:
A self-contained capability with a `SKILL.md` (frontmatter `name`, `description`) + supporting files. Activates via the description string in any agent that reads SKILL.md files.
_Avoid_: command. ("Plugin" is a distinct, related concept — the Claude Code delivery vehicle that bundles Skills; see **Plugin** below.)

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
A platform a skill runs on, grouped by install mechanism. **Filesystem surfaces** install via the `skills` CLI: **Claude Code** — both the CLI *and* the native desktop app, which share `~/.claude/skills/` on a machine (filesystem, hooks) — and **Codex/opencode**. **claude.ai** (the chat app: web/desktop/mobile, no CLI or filesystem) takes uploaded zip Bundles via Settings → Customize → Skills.
_Note_: the **Claude Code desktop app** (a filesystem coding tool) and the **claude.ai desktop app** (the chat app) are different surfaces with different install paths — don't conflate them.
_Avoid_: treating "desktop" as a single surface.

**Bundle (claude.ai)**:
A zip containing one skill's folder at the zip root. Built by `scripts/build-claudeai-zip.sh <skill>`; uploaded by hand via claude.ai Settings → Customize → Skills.

**Plugin**:
The Claude Code packaging unit declared by `.claude-plugin/plugin.json`. This repo ships one Plugin (`stonematt-skills`) that bundles all shipped Skills; Claude Code installs it from the Marketplace. A Plugin is the *delivery vehicle* for Claude Code — distinct from a Skill (the capability it carries). Codex/opencode have no Plugin concept; they consume the same Skills via the `skills` CLI.
_Avoid_: pack, bundle (Bundle is the claude.ai zip).

**Marketplace**:
`.claude-plugin/marketplace.json` — the catalog Claude Code reads when a user runs `/plugin marketplace add stonematt/stonematt-skills`. Lists the `stonematt-skills` Plugin with `source: "./"` (the Plugin is this repo's root). Install with `/plugin install stonematt-skills@stonematt-skills`.

## Relationships

- A **Skill** lives in exactly one **Bucket**.
- Every shipped **Skill**'s directory, `name:`, and slash command share the `stone-` **Namespace**.
- A **Skill** installs into the **Central store** by its namespaced name and is symlinked into each filesystem **Surface**; claude.ai is the exception — it takes an uploaded **Bundle**.

## Example dialogue

> **Matt:** "Why is my commit skill called `stone-commit`?"
> **Agent:** "**Namespace.** The `skills` CLI installs into a flat **Central store** keyed by bare name, so a generic `commit` would clobber another pack's. The `stone-` prefix is collision-proof — you still trigger it by saying 'commit this'; only `/stone-commit` carries the prefix."
> **Matt:** "And on the claude.ai desktop app?"
> **Agent:** "Different **Surface** — the claude.ai chat app, not the Claude Code desktop app. claude.ai has no filesystem, so build a **Bundle** with `build-claudeai-zip.sh stone-commit` and upload it via Settings → Customize → Skills. (The Claude Code desktop app, by contrast, reads `~/.claude/skills/` — same filesystem path as the CLI.)"

## Flagged ambiguities

- "skill" was used to mean both a directory in this repo AND a thing installed in `~/.agents/skills/` (symlinked into each agent). Resolved: a **Skill** is the directory containing `SKILL.md`; "installed skill" is the entry in the **Central store**.

## Scope (locked)

- **In:** 7 `stone-*` skills authored by Matt Stone — `stone-commit`, `stone-merge`, `stone-promote-settings` (engineering); `stone-ai-sniff-test`, `stone-client-report` (productivity); `stone-journal`, `stone-journal-status` (personal).
- **Deferred** (parked on `feat/voice-personas`): the generic `voice` / `email` / `define-voice` skills, `bin/persona-init`, persona-bundling in the zip builder, and ADR-0001 (cross-surface persona architecture). Re-integrate as one unit later.
- **Out:** `continue-after-clear`, `sync-plugin-manifest` (removed — unused). Identity skills `lithos-voice` / `lithos-email` (private dotfiles). Third-party copies (`web-design-guidelines`, `marp-slides`, `excalidraw-diagram`, `mermaid-visualizer`, `obsidian-canvas-creator`, `ux-designer-skill`, `graphify`). Hooks, agents, settings, CLAUDE.md (separate concerns).
