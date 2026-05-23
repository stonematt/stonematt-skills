# <slug> — voice channel

Voice fingerprint for the `<slug>` persona. Loaded by the generic `voice` and
`email` skills via the Resolver. Hand-authored real voice content — keep it free
of secrets you would not upload, since it ships inside claude.ai bundles.

Hybrid shape (ADR-0001): core one-liner + optional audience registers + bullet
style rules + numeric targets + labeled Input/Output few-shot pairs + explicit
anti-patterns.

## Core voice

(One sentence: how this persona sounds at its center. e.g. "Clear, confident,
action-oriented — communicates like a builder who brings people along.")

## Audience registers

Optional. Include only if this voice shifts by audience. Drop the section
entirely for single-register personas.

- **Cold / formal** — (rules for strangers, execs, first contact)
- **Warm** — (rules for peers, repeat collaborators)
- **Internal** — (rules for team, close circle)

## Style rules

- (rule 1 — e.g. first person, present tense)
- (rule 2)
- (rule 3)
- (5 to 15 rules total)

## Numeric targets

- Sentence length: (median words)
- Paragraph count: (range for a short note)

## Few-shot examples

**Input:** (a prompt this persona would respond to)
**Output:** (the response in this persona's voice)

**Input:** (another prompt)
**Output:** (another response)

(3 to 5 pairs — these teach the voice more than any rule)

## Anti-patterns

- Never (open with a specific cliché this persona avoids)
- Never (another tell)
