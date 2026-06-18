# Also publish a Claude Code plugin marketplace

[ADR-0002](./0002-distribute-via-skills-cli-with-stone-namespace.md) made the `skills` CLI (`npx skills@latest add`) the primary install and deliberately kept the Claude plugin path *out* — `.claude-plugin/plugin.json` survived only as the installer manifest, and `/plugin install` was "not the primary path." That holds for portability, but it leaves a gap: friends run a mix of surfaces, including the **Claude Code desktop app**, where opening a terminal to run `npx` is friction. The plugin marketplace is the GUI-native install for exactly that case, and the pack is now play-tested and ready to expand to friends.

We adopt: **publish this repo as a Claude Code plugin marketplace by adding `.claude-plugin/marketplace.json`, listing the existing single `stonematt-skills` plugin with `source: "./"` (the plugin lives at the repo root).** `npx skills@latest add stonematt/stonematt-skills` remains the primary, portable path — it is the only one that also covers Codex and opencode, which have no plugin system. The marketplace is an *additional* path for Claude Code users (CLI or desktop):

```
/plugin marketplace add stonematt/stonematt-skills
/plugin install stonematt-skills@stonematt-skills
```

One `.claude-plugin/plugin.json` serves both ecosystems. Its `skills` array lists each skill by its **direct directory path** (`./skills/engineering/stone-commit`, …). Verified against the Claude Code plugins reference: an explicit `skills` entry may point directly at a directory that contains `SKILL.md`, and because the marketplace entry's `source` resolves to the marketplace root, the explicit list *replaces* the default `skills/` scan — so all seven nested-bucket skills load and nothing is double-scanned. The same direct-path array is what the `skills` CLI already consumes, so the two ecosystems share the key without conflict. Claude Code ignores the extra metadata keys it does not recognise.

## Consequences

- `.claude-plugin/marketplace.json` is maintained alongside `plugin.json`; both enumerate the pack. The pre-merge gate (`scripts/test/validate-skills.test.sh`) now asserts the marketplace name, the single plugin entry, and its `source: "./"`.
- Skills installed via the plugin are namespaced `/stonematt-skills:stone-commit`; via the `skills` CLI they are `/stone-commit`. Natural-language triggers (the `description`) are identical on both paths — only the explicit slash differs.
- Codex and opencode are unaffected: no plugin system, so they stay on the `skills` CLI.
- This **supersedes ADR-0002's** "plugin path out" / "`/plugin install` not the primary path" stance. `npx` stays primary for portability; the plugin marketplace is added, not substituted.
- The shared `plugin.json` `skills` array must stay a list of **direct skill-directory paths**. That format satisfies both the Claude Code loader and the `skills` CLI today; if either ecosystem ever required bucket/scan directories instead, the key would have to be split.
