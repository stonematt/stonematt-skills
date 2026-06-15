---
name: stone-ai-sniff-test
description: >
  A self-review checklist for any drafted prose to catch AI-generated tells before a human sees it.
  Use this skill whenever you've written or are about to deliver written content (emails, posts,
  memos, docs, marketing copy, blog drafts, slack messages, READMEs) and want to make sure it
  doesn't read like AI wrote it. Trigger on phrases like "sniff test this", "smell test", "does
  this sound like AI", "make this sound human", "review my draft for AI tells", or whenever the
  user references the sniff test before publishing or sending. Other skills (e.g. make-screed,
  lithos-email) may invoke this skill as a quality gate.
---

# AI Sniff Test

A reusable quality gate for written content. Run this on any draft before it leaves your hands.

The crude AI tells (delve, tapestry, "navigate the complexities of") are mostly gone from current frontier models. The new failure mode isn't "sounds like a robot." It's "sounds like a capable freelancer who's never met the author." Generic-but-competent. Structurally tidy. Voice-flat. This skill is calibrated for that.

This skill is voice-neutral. It does not impose a tone, register, or aesthetic. It flags patterns that read as machine-generated regardless of subject. Skills that wrap this one (e.g. `make-screed` for counterculture posts, `lithos-email` for consulting comms) layer their own voice rules on top.

## When to Run

- After drafting any meaningful piece of prose (more than a couple of sentences).
- Before writing the draft to a file, sending, posting, or showing the user.
- When the user explicitly asks for a sniff test, smell test, or "does this sound AI."
- As a step inside another skill that needs a quality gate.

If a draft fails more than two of the primary checks below, don't patch individual sentences. The voice is off. Step back and rewrite from the intent, not from an outline.

## Primary Checks (the ones that still matter)

These target how models _think_, not what words they use. Current models can produce technically clean prose that fails every one of these.

### The substitution test

Pick a paragraph. Replace the topic with a completely different one. Does the sentence still work? "This represents a fundamental shift in how we think about [topic]" works for anything, which means it says nothing. Kill it. The paragraph should sound like it belongs in _this specific piece_, written by _this specific person_, about _this specific thing_.

### The paragraph test

Pick any paragraph at random. Could it appear in a generic listicle titled "10 Things Every [Profession] Should Know"? If yes, rewrite. The test is whether the paragraph has a fingerprint or is interchangeable.

### Punchline placement

Find the single best line in the draft. The one someone would screenshot or quote back. If that line is in the middle third of the piece, the structure is wrong. It belongs in the opening hook or the closing beat. Models build _to_ the point. Restructure to start _from_ it.

### Buried lede

If the most interesting claim, observation, or punchline isn't surfaced in the first paragraph or two, restructure. Models default to chronological buildup: context, then explanation, then the interesting part. Readers bail before they get there. Hook first, backstory second.

### First-person voice (vs. editorial board)

If a paragraph talks about "the user" in third person when the author IS the user, rewrite in first person. "The user did the work" vs "I did the work." If a paragraph reads like a position paper or policy recommendation ("the platform should defer to") when it should be a personal observation, rewrite. Tell the story. Don't prescribe the moral. Models drift toward third-person policy register because it feels safer.

### Specificity over abstraction

Models hedge into abstraction unless pushed. Replace generic with concrete:

- "Extensive testing revealed suboptimal results" → "300 test cases, zero triggers."
- "Significant improvements in performance" → "Cut latency from 800ms to 90ms."
- "A wide variety of stakeholders" → "Three engineers, two PMs, the VP of marketing."

If a sentence describes magnitude or quality without a number, name, or specific instance, ask whether it can be made specific. If it can, do it.

### Section silhouette

Scroll through the draft without reading it. Look only at the shapes. If every section is roughly the same height, the same paragraph count, the same density, you have a problem. Models default to "header + two short paragraphs" repeated through the whole piece. Real writing varies: one dense paragraph, then five paragraphs with a code block, then a blockquote and a sentence.

**Paragraph-count check.** Count paragraphs per section (including code blocks and tables as "paragraphs"). If three or more consecutive sections have the same count, you have a grid. Fix one. Merge two short sections, split a long one, drop in a one-liner section. The silhouette should be ragged.

### Resolution addiction

Every section wrapping up neatly is an AI tell. Real prose leaves threads hanging. A section can end mid-thought if the next picks it up. Not every observation needs a concluding sentence. If the closing ties a bow on everything, cut the bow. The best endings leave something unresolved.

### Bumper sticker lines

Lines that sound quotable but say nothing specific. "I'm not mad. I'm building." "The future belongs to those who build it." Could be about anything. If a line works as a motivational poster, cut it. Earn the emotional weight through content, not slogans. This is the most common failure mode in current-model closings.

### Tone calibration

- Hedging where the writer should commit. "This can sometimes be problematic" vs "This is broken."
- Praising both sides to avoid having an opinion. If the piece is meant to take a position, take it.
- Generic enthusiasm. "This is a really exciting development" says nothing. What specifically makes it matter?
- Pure complaint with no path forward. If the piece identifies a problem, point toward a fix, a workaround, or a direction. The reader should leave with something they can do.

## Secondary Checks (cadence and structure)

Less load-bearing than the primary checks, but still worth a pass.

### Cadence

- Three or more sentences in a row with the same structure. Subject-verb-object, subject-verb-object, subject-verb-object reads like a robot.
- Three or more bullet points that open with the same word or grammatical pattern.
- Opening sentences across paragraphs that all follow "Topic sentence introducing the concept." Break the pattern.

### Format trap

- **Bold-numbered lists** ("**1. Do this.** Explanation. **2. Do that.** Explanation.") — the AI's favorite structure for suggestions. It's a listicle. Use paragraphs and let points flow.
- **"Three things, in order of impact:"** is an AI intro sentence. Just start saying the things.
- **Imperative-verb sequences.** Three consecutive paragraphs that each open with a command is a listicle without numbers. Same disease, no formatting. Vary the openings.

## Backstop: Lexical Tells

The crude tells. Current frontier models don't reach for these often, but they still appear. Treat this as a final scan, not the primary defense.

- **Em dashes (`—`).** Claude specifically still overuses these. Rewrite with a period, comma, or new sentence.
- **Semicolons joining independent clauses.** Split into two sentences.
- **Banned transitions:** "furthermore," "moreover," "additionally," "notably," "it's worth noting," "in essence," "fundamentally," "that said," "indeed," "certainly," "essentially."
- **Banned filler vocabulary:** "delve," "leverage," "utilize," "facilitate," "robust," "seamless," "landscape," "paradigm," "holistic," "navigate" (as a metaphor).
- **"It's important to note that"** or any variation. Just say the thing.

If these appear, fix them. But a draft with zero banned words can still fail the substitution test, and that's the bigger problem.

## Do This Instead

When fixing what you find:

- Vary sentence length. A long one followed by a short one. Then medium. Then short again. Like talking.
- Break rhythm on purpose. Start a sentence with "And" or "But" sometimes.
- Be specific. Numbers, names, exact quotes, real instances.
- Use contractions. "Don't" not "do not." "It's" not "it is."
- Let the reader connect dots. Don't explain every implication.
- Read it out loud. If it sounds like a person talking to a smart friend, you're there.

## Calibration

Different contexts have different voice expectations on top of these mechanics. A counterculture zine post and a consulting client email both pass this sniff test the same way. The substitution test applies equally. The silhouette test applies equally. What differs is what comes _after_ the sniff test passes: the contextual voice rules layered on top by the wrapping skill or the user's instruction.

If invoked standalone (no wrapping skill, no user-supplied voice doc), apply the checks neutrally and ask the user to confirm tonal questions before rewriting.

## Output

When this skill runs as a check, produce one of two outcomes:

1. **Pass.** Confirm the draft cleared the checks. Note any judgment calls made.
2. **Findings.** List violations by category, starting with primary checks. Quote the offending passage. Propose a rewrite. Don't rewrite the whole draft unless asked. Surface the tells, fix the worst, let the user decide the rest.
