# CLAUDE.md

## Project

**stonematt-skills** — Public, cross-surface Claude Code / Codex / opencode / claude.ai skills authored by Matt Stone. Pairs with a private `stonematt-skills` dotfiles stow package that holds identity-bearing persona content.

See [`CONTEXT.md`](./CONTEXT.md) for the domain glossary and [`docs/adr/`](./docs/adr/) for architectural decisions.

## Agent skills

### Issue tracker

GitHub Issues + Milestones. PRDs/briefs live in `docs/briefs/`, not as issues. `feature → dev → main` flow (`dev` = integration, `main` = release + GitHub default); releases tagged on `main`. See [`docs/agents/issue-tracker.md`](./docs/agents/issue-tracker.md).

### Triage labels

Nitimini-style `status: *` lifecycle vocabulary; `afk` is an orthogonal flag (`afk-ready` is a legacy alias — migrate it). See [`docs/agents/triage-labels.md`](./docs/agents/triage-labels.md).

### Domain docs

Single-context. Glossary at [`CONTEXT.md`](./CONTEXT.md); briefs in `docs/briefs/` (lazy); ADRs in `docs/adr/`. See [`docs/agents/domain.md`](./docs/agents/domain.md).
