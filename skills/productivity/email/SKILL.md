---
name: email
description: >
  Draft or reply to email in a named persona's voice, with that persona's
  signature and contact block. Generic and identity-free — takes a persona slug
  and resolves both the persona's email.md (signature/contact/format) and
  voice.md (tone) at runtime, so one skill body serves every identity. Use when
  the user says "draft an email as <persona>", "reply as <persona>", "write a
  <persona> email", "send this to <person>", or invokes /email. Pairs with the
  voice generic skill, reusing the same persona voice content.
argument-hint: "--persona <slug> [--skip-sniff] [--register cold|warm|internal] <email request>"
---

# Email (generic)

Tier 1 generic skill. It holds no identity content. It resolves a persona's
`email.md` (email-shape: signature, contact block, sign-off conventions) and
`voice.md` (tone rules) at runtime and composes email in that persona's voice.

See [CONTEXT.md](../../../CONTEXT.md) for the glossary (Persona, Channel,
Resolver, Tier 1/2, Surface, Bundle) and
[ADR-0001](../../../docs/adr/0001-cross-surface-persona-architecture.md) for the
architecture.

## Arguments

- `--persona <slug>` *(optional if a default is set)* — the persona to write as
  (e.g. `lithos`, `nwhub`). The slug keys the Resolver lookup.
- `--skip-sniff` *(optional)* — bypass the `ai-sniff-test` quality gate. Use for
  short replies or fast iteration. Long-form output runs the gate by default.
- `--register <cold|warm|internal>` *(optional)* — audience register hint. If
  omitted, infer from the request; when uncertain, default to `cold` (easier to
  warm up in a follow-up than to dial back over-familiarity).

**Resolving the persona when `--persona` is omitted:** fall back to the
`$STONEMATT_DEFAULT_PERSONA` env var. If set, use it and tell the user which
persona you defaulted to. Only if both the flag and the env var are unset, stop
and ask. Never guess a slug.

## Steps

### 1. Resolve the persona files

Run the bundled resolver from this skill's directory, once per channel:

```bash
"$SKILL_DIR/scripts/resolve-persona.sh" <slug> email
"$SKILL_DIR/scripts/resolve-persona.sh" <slug> voice
```

The resolver prints the resolved path on stdout (exit 0) or, on no hit, prints
all four attempted paths to stderr (exit 1). The chain (first hit wins):

1. `$STONEMATT_SKILLS_CONFIG/persona/<slug>/<channel>.md` (env override)
2. `${XDG_CONFIG_HOME:-$HOME/.config}/stonematt-skills/persona/<slug>/<channel>.md`
3. `$SKILL_DIR/persona/<slug>/<channel>.md` (claude.ai bundle)
4. `./persona/<slug>/<channel>.md` (cwd / dev fixture)

**`voice.md` is required; `email.md` is optional.** If `voice.md` does not
resolve, surface the resolver's stderr verbatim and stop. If `email.md` does not
resolve, proceed with voice only and note that no email-specific signature/contact
was found (the user can author one with `define-voice --channel email` once that
channel exists, or add `email.md` to the persona dir).

### 2. Load the persona files

Read both resolved paths. `voice.md` supplies the tone (style rules, numeric
targets, few-shot pairs, anti-patterns). `email.md` supplies the email-shape:
signature, contact block, greeting/sign-off conventions, length norms. Treat
both as authoritative for this run; on any conflict, `email.md` wins for
format/structure and `voice.md` wins for tone.

### 3. Compose the email

1. **Identify the register** (cold/formal, warm, internal) from `--register` or
   the request. This is the most load-bearing choice — it sets opener, humor,
   and how much credibility-building precedes the ask.
2. **Identify the purpose** in one sentence; surface it in the lede, not buried.
3. **Draft** the email following `voice.md`'s rules and `email.md`'s structure:
   register-appropriate greeting, purpose-first body, concrete CTA, the persona's
   signature and contact block from `email.md`.

### 4. Quality gate

For anything longer than a short reply, run the draft through the `ai-sniff-test`
skill before showing it. Apply the persona voice rules on top of whatever the
sniff test flags — the sniff test is voice-neutral; this skill supplies the voice.

Skip the gate when `--skip-sniff` is passed or for a one- or two-line reply.

### 5. Show, never send

Show the draft to the user. Never send, post, or commit it without explicit
approval.

## Notes

- The Resolver is replicated per generic skill (this skill carries its own copy
  under `scripts/`) so each skill is self-contained inside a claude.ai bundle —
  no cross-skill imports. The `voice` generic skill carries its own copy.
- On claude.ai, build a bundle with `scripts/build-claudeai-zip.sh email <slug>`
  so both `email.md` and `voice.md` ship under `$SKILL_DIR/persona/<slug>/` (path 3).
- To author the persona's voice, use `define-voice --persona <slug>`. The
  `email.md` channel (signature/contact) is authored alongside it in the same
  persona directory.
