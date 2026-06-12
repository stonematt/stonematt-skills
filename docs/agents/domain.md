# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Layout: single-context

This repo is a single skill bundle; there are no sub-contexts. Layout:

```
/
├── CONTEXT.md                  ← glossary of domain terms
├── docs/
│   ├── briefs/                 ← PRDs / scoped initiatives (lazy)
│   │   └── <name>.md
│   ├── adr/                    ← architectural decision records
│   │   └── 0002-distribute-via-skills-cli-with-stone-namespace.md
│   └── agents/                 ← agent skill configuration (this folder)
├── skills/
│   └── <bucket>/<skill>/SKILL.md
├── scripts/
└── bin/
```

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the canonical glossary. Use its vocabulary (**Skill**, **Bucket**, **Namespace**, **Central store**, **Surface**, **Bundle**) in any output (issue titles, refactor proposals, hypotheses, test names).
- **`docs/adr/`** — ADRs that touch the area you're about to work in. ADR-0002 covers distribution via the `skills` CLI and the `stone-` namespace.
- **`docs/briefs/<name>.md`** — if the work relates to a current initiative, read the brief for the why and architecture. May not exist yet — created lazily by `/to-prd`.

If any of these files don't exist, **proceed silently**. Don't flag absence; don't suggest creating them upfront. The producer skills (`/grill-with-docs`, `/to-prd`) create them lazily.

## Use the glossary's vocabulary

When an output names a domain concept, use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids:

- **Skill** — not "command" or "plugin"
- **Bucket** — not "category" or "group"
- **Namespace** — not "scope" or "vendor-prefix"
- **Central store** — not "registry" or "cache"

If a concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/grill-with-docs`).

## Flag ADR conflicts

If output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0002 — but worth reopening because…_

Only surface when the friction is real enough to warrant revisiting the ADR. Don't list every theoretical refactor an ADR forbids.

## Resolved ambiguities

Already in `CONTEXT.md` under "Flagged ambiguities" — don't re-litigate:

- **"skill"** — the directory in this repo containing `SKILL.md` vs the installed copy at `~/.claude/skills/`. Use "skill" for the source-of-truth dir; "installed skill" for the target.
