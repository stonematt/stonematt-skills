# MVP Dogfood

Ship the current `stonematt-skills` pack to `main` so Matt can dogfood it across filesystem agents without waiting on broader cross-surface polish. The MVP is a coherent, installable skill pack with a lightweight pre-merge health gate; it is not a claim that every skill is broadly portable or that claude.ai bundles are fully validated.

## Scope

### In

- Seven `stone-*` Skills listed in `CONTEXT.md`.
- Engineering Bucket: `stone-commit`, `stone-merge`, `stone-promote-settings`.
- Productivity Bucket: `stone-ai-sniff-test`, `stone-client-report`.
- Personal Bucket: `stone-journal`, `stone-journal-status`.
- Filesystem-agent install via `npx skills@latest add stonematt/stonematt-skills`.
- Installer manifest at `.claude-plugin/plugin.json`.
- Local dogfood install via `scripts/link-skills.sh`.
- Lightweight pre-merge gate via `scripts/test.sh`.

### Out

- Hardening claude.ai upload compatibility beyond the existing best-effort zip builder.
- Re-integrating deferred persona skills from `feat/voice-personas`.
- Adding Agents, including the sketched `code-explorer` agent.
- Behavioral fixture tests for each procedural skill.
- Public marketplace polish beyond accurate README and Bucket indexes.

## Decisions

- `personal/` means environment-coupled, not excluded from dogfooding.
- `stone-journal` and `stone-journal-status` live in `personal/` because they depend on local transcript, memory, and worktree conventions.
- claude.ai support remains best-effort/manual for MVP.
- Active agent docs should use only current glossary terms; deferred persona terms remain only as deferred context.
- The MVP ship gate is structural validation, not behavior perfection.

## Ship Checklist

- `README.md` lists all shipped Skills under the correct Buckets.
- Each Bucket README lists its shipped Skills.
- `CONTEXT.md` scope matches the repository contents.
- `docs/agents/` does not describe deferred persona architecture as active.
- `.claude-plugin/plugin.json` lists all shipped Skills.
- `scripts/link-skills.sh` includes `personal/`, excludes only `deprecated/` and `in-progress/`, and links Claude/Codex stores.
- `./scripts/test.sh` passes.

## Follow-Up Candidates

- Add behavior fixture tests after dogfooding reveals concrete failure modes.
- Validate claude.ai bundle compatibility against the current uploader.
- Decide whether Agents belong in this repo or in private dotfiles.
- Reintegrate persona skills as one explicit scoped initiative.
