---
name: define-voice
description: >
  Author or amend a persona's voice — the tone rules the generic `voice` and
  `email` skills apply. Interviews you (or learns from writing samples) to
  produce a hybrid-shape voice.md: core one-liner, style rules, numeric targets,
  few-shot pairs, anti-patterns. Writes to the private persona path, never the
  public repo. Use when the user says "define a voice", "create a new
  voice/persona", "set up my voice", "author the <persona> voice", "amend my
  voice", "tune/edit the <persona> voice", or invokes /define-voice. Pairs with
  the `voice` skill, which reads what this skill writes.
argument-hint: "--persona <slug> [--channel voice] [--from <samples-file>]"
---

# Define voice (authoring)

The authoring counterpart to the generic `voice` skill. `voice` *applies* a
persona's `voice.md`; this skill *writes* it. Use it to create a brand-new voice
or amend an existing one. It holds no identity content — the content it produces
lives in the private persona path, keeping the public repo identity-free.

See [CONTEXT.md](../../../CONTEXT.md) for the glossary (Persona, Channel,
Resolver) and
[ADR-0001](../../../docs/adr/0001-cross-surface-persona-architecture.md) for the
architecture and the hybrid-shape rationale.

## Arguments

- `--persona <slug>` **(required)** — which persona's voice to author. Lowercase
  letters/digits/hyphens, starting with a letter (e.g. `lithos`, `nwhub`). If
  missing, ask for it. Do not guess.
- `--channel <name>` *(optional, default `voice`)* — the channel file to author.
  `voice` is the tone fingerprint; `email` adds signature/contact (author that
  through this skill too once the email channel exists).
- `--from <file>` *(optional)* — a file of existing writing samples. When given,
  infer the voice rules from the samples and confirm them with the user instead
  of interviewing cold.

## Steps

### 1. Resolve the write destination

Run the bundled write-path resolver from this skill's directory:

```bash
"$SKILL_DIR/scripts/resolve-write-path.sh" <slug> <channel> --mkdir
```

It prints the single canonical write path (env override `$STONEMATT_SKILLS_CONFIG`
first, else `$XDG_CONFIG_HOME/stonematt-skills/persona/<slug>/<channel>.md`) and
creates the parent dir. This is always a **private** location outside this repo;
if it is a stow symlink into a dotfiles source, edits land in the
version-controlled dotfiles tree.

### 2. Decide create vs. amend

Check whether the destination already exists (`test -f <path>`).

- **Absent → create mode.** Go to step 3.
- **Exists → amend mode.** Read the current file, show the user its sections,
  and go to step 4.

### 3. Create mode — author from scratch

Seed from the bundled skeleton at `$SKILL_DIR/template/voice.md` — it carries the
hybrid shape. Fill it by **interviewing the user inline in chat** (one focused
question at a time, not a wall of questions), or by inferring from `--from`
samples and confirming. Cover, in order:

1. **Core voice** — one sentence: how this persona sounds at its center.
2. **Audience registers** *(optional)* — does the voice shift for cold/formal vs.
   warm vs. internal audiences? If not, drop the section.
3. **Style rules** — 5 to 15 concrete bullets (person, tense, sentence shape,
   opener habits, what carries the warmth). Concrete beats abstract.
4. **Numeric targets** — median sentence length, paragraph count for a short note.
5. **Few-shot examples** — 3 to 5 labeled Input/Output pairs. These teach the
   voice more than any rule; push for real ones the user has written.
6. **Anti-patterns** — specific tells this persona never does ("never open with
   'I just wanted to…'"). Name the cliché, don't describe it abstractly.

Write the completed file to the destination from step 1.

### 4. Amend mode — edit in place

Load the existing file. Apply the user's requested change (add a rule, fix a
register, swap a few-shot pair, add an anti-pattern). **Preserve the hybrid
shape and all untouched sections** — edit surgically, don't rewrite wholesale
unless asked. Write the result back to the same path.

### 5. Confirm and hand off

After writing, tell the user:

- The path written, and that the generic `voice --persona <slug>` skill will now
  resolve it.
- If the path is a stow symlink source (dotfiles), no further action — edits are
  already in the dotfiles tree; commit them there.
- If they authored content meant for claude.ai, they can bundle it with
  `scripts/build-claudeai-zip.sh voice <slug>`.

## Notes

- **Never write identity content into this public repo.** The write-path
  resolver only targets the env override or XDG path — both private. Do not
  write a persona file under `skills/` or commit one here.
- The write-path resolver is intentionally two-deep (env → XDG), unlike the
  read-side `voice` Resolver (four paths). An author needs one unambiguous
  destination; a reader needs fallbacks.
- This skill is self-contained (bundled resolver + template) so it works inside a
  claude.ai bundle with no cross-skill imports, matching the `voice` convention.
