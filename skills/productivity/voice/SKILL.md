---
name: voice
description: >
  Apply a named persona's voice to drafted prose, or review prose against that
  persona's voice rules. Generic and identity-free — takes a persona slug and
  resolves the persona's voice file at runtime, so one skill body serves every
  identity. Use when the user says "write in my voice", "write as <persona>",
  "draft this as <persona>", "review for voice", "does this sound like
  <persona>", or invokes /voice. Requires a --persona <slug> argument. Pairs
  with the email generic skill, which reuses the same persona content.
argument-hint: "--persona <slug> [--skip-sniff] <draft or review request>"
---

# Voice (generic)

Tier 1 generic skill. It holds no identity content. It resolves a persona's
`voice.md` at runtime and applies it — either to draft new prose in that voice,
or to review existing prose against that voice's rules.

See [CONTEXT.md](../../../CONTEXT.md) for the glossary (Persona, Channel,
Resolver, Tier 1/2, Surface, Bundle) and
[ADR-0001](../../../docs/adr/0001-cross-surface-persona-architecture.md) for the
architecture.

## Arguments

- `--persona <slug>` *(optional if a default is set)* — the persona whose voice
  to apply (e.g. `nwhub`, `lithos`). The slug keys the Resolver lookup.
- `--skip-sniff` *(optional)* — bypass the `ai-sniff-test` quality gate. Use for
  short-form output or fast iteration. Long-form output runs the gate by default.

**Resolving the persona when `--persona` is omitted:** fall back to the
`$STONEMATT_DEFAULT_PERSONA` env var. If it is set, use it and tell the user
which persona you defaulted to ("Using your default persona: `lithos`"). Only if
both the flag and the env var are unset, stop and ask. Never guess a slug.

## Steps

### 1. Resolve the persona voice file

Run the bundled resolver from this skill's directory:

```bash
"$SKILL_DIR/scripts/resolve-persona.sh" <slug> voice
```

where `$SKILL_DIR` is the directory containing this `SKILL.md`. The resolver
prints the resolved path on stdout (exit 0) or, on no hit, prints all four
attempted paths to stderr (exit 1).

The Resolver checks, in order, first hit wins:

1. `$STONEMATT_SKILLS_CONFIG/persona/<slug>/voice.md` (env override)
2. `${XDG_CONFIG_HOME:-$HOME/.config}/stonematt-skills/persona/<slug>/voice.md`
3. `$SKILL_DIR/persona/<slug>/voice.md` (claude.ai bundle)
4. `./persona/<slug>/voice.md` (cwd / dev fixture)

If the resolver exits non-zero, surface its stderr verbatim to the user — it
tells them whether this is missing content or a misconfigured env var. Stop.

### 2. Load the voice file

Read the resolved path. It carries the hybrid shape: bullet style rules,
numeric targets, labeled Input/Output few-shot pairs, and anti-patterns. Treat
the whole file as the authoritative voice spec for this run.

### 3. Apply the voice

**Draft mode** (user wants new prose): write the requested content following the
voice file's rules, hitting its numeric targets, mirroring the few-shot
Input/Output pairs, and avoiding every listed anti-pattern.

**Review mode** (user wants a critique): use the voice file as a rubric. Flag
each place the draft violates a rule or trips an anti-pattern. Quote the
offending passage, name the rule, propose a fix. Don't rewrite wholesale unless
asked.

### 4. Quality gate

For long-form output (more than a couple of sentences) in draft mode, run the
draft through the `ai-sniff-test` skill before showing it. Apply the persona
voice rules on top of whatever `ai-sniff-test` flags — the sniff test is
voice-neutral; this skill supplies the voice.

Skip the gate when `--skip-sniff` is passed, or for short-form output (a one- or
two-sentence reply, a slack-style line).

## Notes

- The Resolver is replicated per generic skill (this skill carries its own copy
  under `scripts/`) so each skill is self-contained inside a claude.ai bundle —
  no cross-skill imports. The `email` generic skill carries its own copy.
- On claude.ai, build a bundle with `scripts/build-claudeai-zip.sh voice <slug>`
  so the persona file ships under `$SKILL_DIR/persona/<slug>/voice.md` (path 3).
