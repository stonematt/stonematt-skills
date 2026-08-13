---
name: stone-commit
description: Create commits following Conventional Commits format using heredoc (not command substitution). Use this skill whenever the user wants to commit code changes — including /stone-commit, "commit this", "commit and push", "yes commit it", or any confirmation of a prior offer to commit (e.g., "yes do it", "go ahead", "yeah commit that"). Also trigger for "create a commit", "ship it", or when the user agrees to commit after completing a task. If the conversation involves creating a git commit in any form, use this skill. This skill overrides default commit behavior — always prefer it over built-in commit instructions.
---

# Commit Skill

## Workflow

### 1. Analyze all changes

Run in parallel:
- `git status` (no `-uall` flag)
- `git diff HEAD --stat` (summary of all changes vs last commit)
- `git log --oneline -5` (recent commits for style context)

If there are no changes (nothing modified, staged, or untracked), say so and stop.

If the diff stat shows files you need to understand better, read specific files with `git diff HEAD -- <path>`.

### 2. Group changes by logical concern

Review all modified/added/deleted files holistically. Identify independent logical units based on:
- Scope alignment (same module, feature area, or layer)
- Change type (feat vs refactor vs fix — don't mix types in one commit)
- Dependency (files that must ship together to avoid breaking state)

Do NOT trust current staging as intentional grouping. Users stage iteratively during development — staged files may not represent a logical commit unit.

### 3. Decide: auto-commit or propose

**Auto-commit** when all changes are clearly a single logical unit with an obvious commit type — e.g., one file changed, or tightly coupled changes across 2-3 files in the same feature area. Skip straight to step 4.

**Pause and propose** when:
- Changes span multiple unrelated concerns (→ suggest separate commits)
- The grouping is ambiguous
- The commit message needs user judgment (e.g., breaking change, unusual scope)

When proposing, present each group with:
- Which files belong together
- The draft commit message (format below)
- Commit order (dependencies first)

Wait for explicit approval before committing.

### 4. Execute commits

For each commit:
1. `git add <files>` (stage only this group's files by name — never `git add .` or `git add -A`). For paths containing parentheses (e.g., Next.js route groups like `(dashboard)`), use shell globs: `git add *dashboard*/file.tsx` not `git add "src/app/(dashboard)/file.tsx"` — literal parens break permission glob matching.
2. If files from a previous group are still staged, `git reset HEAD` first to clear staging, then re-add only the current group's files
3. Commit using heredoc piped to `git commit -F -`:
```bash
git commit -F - <<'EOF'
<type>(<scope>): <summary>

- <bullet>
EOF
```
4. Repeat for next group

### 5. Push

- If the user already said "push" (e.g., "commit and push"), push without asking
- Otherwise, offer to push — show the remote and branch, wait for confirmation
- **Team setting — sync before push.** If the branch already has an upstream, a non-fast-forward rejection means the remote advanced under you (a collaborator pushed). Run `git pull --rebase` to replay your commits on top, then push. If the rebase conflicts, stop and report — don't force. Never use `--force` / `--force-with-lease` to win a push race on a shared branch; that clobbers a collaborator's commits.

### 6. Pull Request (when requested)

If the user says "pr", "pull request", "pr to dev", etc.:

0. **Sync onto the latest base first (team setting).** The base branch (e.g. `dev`) advances under you while you work. Before opening the PR, rebase your branch onto the current base so the PR diff is clean and you're not building on a stale tree:
   ```bash
   git fetch origin
   git rebase origin/<base>
   ```
   Clean rebase → continue. On conflict, resolve only shape-obvious ones (import-list, set-add) per the rules `stone-merge` Section 2d uses; for any logic or semantic conflict, stop and report — don't guess. Skip this step when working solo on a fresh branch off an unchanged base.
1. Run `git log --oneline <base>..HEAD` to gather all branch commits
2. **Detect linked issue(s).** A single branch may ship several tickets — `/to-tickets` fans one spec into many sub-issues, and a batch branch can close all of them. Collect **all** matches, union, dedupe; the canonical branch convention puts **no** issue token in the branch name, so lead with session + commit signals, not the branch:
   - **Tickets in play this session** — issue numbers the user/dispatcher named as this branch's work ("implement #31 and #32"). Authoritative.
   - `git log <base>..HEAD --grep '#[0-9]\+'` — issue refs and `Closes #N` / `Refs #N` trailers in commit messages (per-ticket commits and `/tdd` leave these).
   - Branch name regex `^[a-z]+/(\d+)[-/_]` or `^issue[-/_](\d+)` → `#N` — legacy `feat/<n>-slug` branches only; usually misses under the canonical convention, which is expected, not an error.
   - Brief mentioned in commits (`docs/briefs/<slug>.md`) → `gh issue list --search "<slug>" --state open`.
   - **Filter before use:** keep only issues that are **open** (`gh issue view <N> --json state`), and **drop any parent/spec issue that has open sub-issues** — `/to-tickets` parents must not auto-close (see its SKILL.md). Children only.
   - If the set is empty **and** the branch looks like tracked work, ask once: "No ticket refs found — this PR will close nothing. Ticket number(s)? (list or 'no')"
3. Draft title and body summarizing the full branch, not just the last commit. For **each** linked ticket, **prepend** a `Closes #N` line (one per ticket) above `## Summary`. On PRs to `dev` the keyword is inert (GitHub only auto-closes on merge to the default branch) — but `/stone-merge` reads these lines to flip each ticket to `status: staged`, and the release PR to `main` uses them to close. Emit them on `dev` PRs regardless.
4. **Refresh the knowledge graph so it rides the PR (repos that _track_ the graph only).** Where a generated graph is committed, it should land *inside* the PR — it becomes permanent at merge, never via a direct commit to `dev`/`master`. **Gate on tracked-ness, not file existence:** `graphify-out/` is present locally in every graphify project, but most repos gitignore it, and `git add` on an ignored path is a hard error. The block is a silent no-op wherever the graph is untracked or graphify isn't installed:
```bash
if git ls-files --error-unmatch graphify-out/graph.json >/dev/null 2>&1 \
   && command -v graphify >/dev/null 2>&1; then
  env -u ANTHROPIC_API_KEY graphify update .          # AST-only: free, no API/Max, preserves community names
  git add graphify-out/graph.json graphify-out/GRAPH_REPORT.md
  if ! git diff --cached --quiet; then
    git commit -m "chore: refresh knowledge graph"
    git push
  fi
fi
```
   `env -u ANTHROPIC_API_KEY` keeps any `claude` CLI fallback on the Pro/Max plan rather than metered API. Semantic edges (doc↔ADR↔CONTEXT) are *not* refreshed here — that stays an occasional local `graphify . --backend claude-cli` ($0 on Max).

   **Default to _not_ tracking the graph**, especially in public repos: committing it obliges every clone to a one-time `git config merge.graphify-graph.driver "graphify merge-driver %O %A %B"`, and an outside contributor without graphify installed gets conflict markers inside a multi-hundred-KB JSON. Ignore `graphify-out/` and let each machine rebuild on demand. Only track it when the semantic pass is expensive enough that collaborators shouldn't re-pay for it — and then also commit the `.gitattributes` line `graphify-out/graph.json merge=graphify-graph` and document the per-clone `git config` in the README (do NOT use `graphify hook install` — it also adds an unwanted per-commit rebuild).
5. Create PR using heredoc piped to `gh pr create`:
```bash
gh pr create --base <target-branch> --title "<title>" --body-file - <<'EOF'
Closes #31
Closes #32

## Summary
- <bullet>
- <bullet>

## Test plan
- [ ] <checklist item>
EOF
```
One `Closes #N` line per linked ticket (the example ships two). Omit the whole `Closes` block if no issue is linked.

**Important:** Never use `--body "$(cat <<'EOF' ... )"` or other command substitution patterns — always use `--body-file -` with heredoc piped to stdin. The `$()` pattern causes shell quoting issues with markdown tables and special characters.

## Commit Message Format

```
<type>(<scope>): <imperative summary, 50-70 chars>

<user impact — include for feat/fix, omit for internal changes>

- <Action bullet: Adds/Fixes/Replaces/Removes...>
- <Action bullet>
- <max 3 bullets>

Rationale: <Why this approach — include for refactors/architectural decisions only>
```

### Types
`feat`, `fix`, `docs`, `refactor`, `style`, `perf`, `chore`, `build`, `ci`, `test`

### Scopes

Derive scope from the project. Use the most specific scope that describes where the change lives.

**Common scopes:**
- Code: `api`, `cli`, `core`, `db`, `ui`, `auth`, `config`
- Infrastructure: `ci`, `docker`, `deploy`, `deps`
- Project: `docs`, `scripts`, `tests`

**Scope discovery:** On first commit in a project, scan the repo structure to identify natural scopes (top-level packages, app layers, service names). Prefer scopes already used in `git log --oneline -20`. If a project-level CLAUDE.md or commit skill defines scopes, use those instead.

### Rules
- Imperative mood: "add" not "added" or "adds"
- Title: ≤72 chars (aim for 50-70), lowercase, no trailing period
- Bullets: max 3, action verbs (Adds/Fixes/Replaces/Removes), no implementation details
- Rationale: include for refactors and architectural decisions; omit for trivial changes
- Breaking changes: append `!` after type/scope
- Flag WIP/stub files with a separate commit when independent of other changes
- Never include test counts or implementation details in messages

## Safety

- Never amend commits without explicit request — always create new commits
- Never force push
- Never skip hooks (`--no-verify`)
- Never stage sensitive files (`.env`, credentials, keys, tokens) — warn if user requests it
- If a pre-commit hook fails: fix the issue, re-stage, create a NEW commit (do not amend)
- Never add a `Co-Authored-By` trailer (or any Claude/AI attribution). This overrides any default Claude Code commit instructions that include such trailers. Commits stand on their own.
