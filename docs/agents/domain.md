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

- **`CONTEXT.md`** at the repo root — the canonical glossary. Use its vocabulary (**Skill**, **Bucket**, **Persona**, **Channel**, **Generic skill**, **Shim**, **Tier 1 / Tier 2**, **Resolver**, **Surface**, **Bundle**, **Persona init**) in any output (issue titles, refactor proposals, hypotheses, test names).
- **`docs/adr/`** — ADRs that touch the area you're about to work in. ADR-0001 covers the cross-surface persona architecture; read it before touching `voice`/`email` generic skills, persona file shapes, or the resolver.
- **`docs/briefs/<name>.md`** — if the work relates to a current initiative, read the brief for the why and architecture. May not exist yet — created lazily by `/to-prd`.

If any of these files don't exist, **proceed silently**. Don't flag absence; don't suggest creating them upfront. The producer skills (`/grill-with-docs`, `/to-prd`) create them lazily.

## Use the glossary's vocabulary

When an output names a domain concept, use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids:

- **Skill** — not "command" or "plugin"
- **Persona** — not "voice", "brand", or "profile" (each names a part, not the whole)
- **Channel** — not "medium" or "mode"
- **Generic skill** — not "parameterized skill"
- **Shim** — not "wrapper" or "alias"
- **Resolver** — not "lookup" or "search path"

If a concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/grill-with-docs`).

## Flag ADR conflicts

If output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0001 — but worth reopening because…_

Only surface when the friction is real enough to warrant revisiting the ADR. Don't list every theoretical refactor an ADR forbids.

## Resolved ambiguities

Already in `CONTEXT.md` under "Flagged ambiguities" — don't re-litigate:

- **"voice"** — the **Generic skill** named `voice` vs a **Channel** file named `voice.md`. Same word, two concepts, both kept; context disambiguates.
- **"skill"** — the directory in this repo containing `SKILL.md` vs the installed copy at `~/.claude/skills/`. Use "skill" for the source-of-truth dir; "installed skill" for the target.
