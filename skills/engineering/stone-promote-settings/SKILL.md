---
name: stone-promote-settings
description: >
  Reconcile Claude Code settings.local.json (personal, gitignored) against
  settings.json (repo-tracked, shared): diff the two, promote stable rules to
  the shared file, drop duplicates, and flag secrets/machine-specific paths to
  keep local. Use when the user says "promote settings", "review settings",
  "clean up settings", "sync settings", "promote permissions", or asks about
  moving local settings to repo-tracked settings. This skill owns the
  local-to-shared promotion diff — a niche neither built-in covers. NOT for:
  editing settings.json in place, moving a permission to user scope, or adding
  env vars/hooks (use the update-config skill); auto-generating an allowlist
  from transcript noise to cut permission prompts (use /fewer-permission-prompts,
  which writes new rules to project settings.json but does not reconcile your
  existing local vs repo files).
---

# Promote Settings

You are a settings management agent for Claude Code projects. Your job is to compare `.claude/settings.local.json` (user-specific, gitignored) with `.claude/settings.json` (repo-tracked, shared) and help the user promote stable permissions and settings from local to repo scope.

## Two-Phase Workflow

### Phase 1: Analyze and Propose

1. **Read both files.** Read `.claude/settings.json` and `.claude/settings.local.json` in the current project root. If either doesn't exist, note that.

2. **Read `.gitignore`.** Check whether `settings.local.json` is already gitignored. Flag if it isn't.

3. **Diff the settings.** For each section, identify:
   - **Local-only rules** — in local but not in repo. These are promotion candidates.
   - **Repo-only rules** — in repo but not in local. Already tracked; no action needed.
   - **Duplicates** — identical rules in both files. These can be cleaned from local.
   - **Conflicts** — rules where local and repo disagree (e.g., local allows something repo denies). Flag for user decision.

4. **Present the promotion plan** as a table grouped by settings section:

   ```
   ### Permissions: allow
   | Rule | Status | Recommendation |
   |------|--------|----------------|
   | `Bash(npm run *)` | local-only | Promote to repo |
   | `Edit` | duplicate | Remove from local |
   | `Bash(rm -rf *)` | conflict (repo denies) | Keep in local only |
   ```

   Repeat for `permissions.deny`, `permissions.ask`, and any non-permission settings keys (env, hooks, MCP servers, sandbox, etc.).

5. **Flag sensitive items.** Some settings should stay local:
   - Rules containing tokens, secrets, or credentials
   - Machine-specific paths (e.g., absolute paths with usernames)
   - `env` values with API keys or tokens
   - Personal MCP server configs pointing to local services
   - `apiKeyHelper` or `awsCredentialExport` with user-specific scripts

   Mark these as "Keep in local" with a brief reason.

6. **Propose .gitignore update** if `settings.local.json` is not already gitignored.

7. **Stop and ask the user to review.** Do not modify files until the user confirms.

### Phase 2: Execute (after approval)

For each approved promotion:

1. **Add the rule to `settings.json`.** Read the current file, add the rule to the appropriate array/section, and write it back. Preserve existing formatting and key order.

2. **Remove the rule from `settings.local.json`.** If a promoted rule was the only item in a section, remove the empty section. If the file becomes empty (just `{}`), delete it.

3. **Update `.gitignore`** if needed — add `.claude/settings.local.json` if not present.

4. **Report each change:**
   - "Promoted `Bash(npm run *)` to repo settings"
   - "Removed duplicate `Edit` from local settings"
   - "Added `.claude/settings.local.json` to .gitignore"

5. **Show final state** — display the resulting `settings.json` and `settings.local.json` (or note it was deleted).

## Rules

- **Never auto-promote sensitive items.** Always flag them and let the user decide.
- **Preserve JSON formatting.** Use 2-space indentation, keep arrays on separate lines for readability.
- **permissions arrays merge across scopes** — a rule in repo settings applies even without being in local. Duplicates are safe to remove from local.
- **deny takes precedence over allow** in evaluation order. If repo denies something and local allows it, local wins (higher precedence). Flag this as a conflict rather than silently promoting.
- **Don't touch `~/.claude/settings.json`** (user-level). This skill only manages project-level files.
- **Create `settings.json` if it doesn't exist** and there are rules worth promoting.
- **Use the Read and Edit tools** for file modifications, not Bash with echo/cat.

## Edge Cases

- **No local file exists:** Report "No settings.local.json found — nothing to promote." and exit.
- **No repo file exists:** Offer to create one with all promotable rules from local.
- **Files are identical:** Remove local (it's fully redundant) and confirm.
- **Local has settings beyond permissions** (e.g., hooks, MCP, sandbox): Handle each section independently. Non-permission settings follow the same promote/keep/conflict logic.
