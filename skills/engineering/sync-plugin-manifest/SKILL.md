---
name: sync-plugin-manifest
description: >
  Export the current host's installed Claude Code plugins to a churn-free
  manifest tracked in the dotfiles repo. Use when the user says
  "sync plugins", "export plugin manifest", "update plugin list",
  or before committing in the dotfiles repo so the tracked manifest
  reflects the current host's installed plugin set.
---

# Sync Plugin Manifest

The source of truth for installed plugins on a host is `~/.claude/plugins/installed_plugins.json`. That file contains host-specific paths (`installPath`) and timestamps (`installedAt`, `lastUpdated`) that churn on every plugin check, making it unsuitable for tracking in git.

This skill produces a clean, deterministic manifest at `<dotfiles-repo>/claude/dot-claude/plugins/plugins.manifest.json` that contains only the fields needed to recreate the plugin set on another host.

## Preconditions

- Current working directory is the dotfiles repo root (contains `packages_to_stow`). If not, ask the user to `cd` there first.
- `~/.claude/plugins/installed_plugins.json` exists. If not, report that and stop.

## Steps

1. **Read** `~/.claude/plugins/installed_plugins.json`.

2. **Transform** each entry in `plugins`:
   - Split the key `"name@marketplace"` on the last `@` → `name`, `marketplace`.
   - Each value is an array of install records. For each record, emit:
     ```json
     { "name": "...", "marketplace": "...", "version": "...", "scope": "..." }
     ```
   - Drop `installPath`, `installedAt`, `lastUpdated`, `gitCommitSha` — these are host-specific or churn.

3. **Sort** the resulting list by `marketplace`, then `name`, then `scope`. Stable ordering = no spurious diffs.

4. **Write** to `claude/dot-claude/plugins/plugins.manifest.json` with 2-space indent and a trailing newline.

5. **Diff & report:** run `git diff --no-color claude/dot-claude/plugins/plugins.manifest.json` and show the user what changed. If nothing changed, say so. Remind the user to include the manifest in their next commit if it changed.

## Manifest format

```json
{
  "plugins": [
    {
      "name": "frontend-design",
      "marketplace": "claude-plugins-official",
      "version": "unknown",
      "scope": "user"
    }
  ]
}
```

## Rules

- Never write `installPath`, `installedAt`, `lastUpdated`, or `gitCommitSha` to the manifest.
- Never read/write the manifest from a path outside the dotfiles repo.
- If a plugin has multiple install records (e.g., different scopes), emit each as a separate entry — don't collapse them.
- This skill is one-way (host → repo). Installing plugins from the manifest on a fresh host is a separate, future skill.

## Integration with PR workflow

Run this skill before committing in the dotfiles repo when you've added/removed/updated plugins. The manifest diff becomes part of the PR, giving other hosts a reviewable record of the plugin set.
