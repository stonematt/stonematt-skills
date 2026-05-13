---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

<!--
  Local shadow of upstream `handoff` skill from mattpocock/skills.
  Reason: upstream uses `mktemp -t handoff-XXXXXX.md`, which is broken on BSD/macOS mktemp.
  Upstream issue: https://github.com/mattpocock/skills/issues/175
  Remove this shadow once upstream lands the portable form.
-->

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to a path produced by:

```bash
tmp=$(mktemp "${TMPDIR:-/tmp}/handoff-XXXXXX") && mv "$tmp" "$tmp.md" && printf '%s\n' "$tmp.md"
```

This form works under both GNU and BSD `mktemp` (macOS `/usr/bin/mktemp` treats `-t` as a literal prefix and appends a random suffix, which breaks the upstream `mktemp -t handoff-XXXXXX.md` form by leaving `XXXXXX` literal and putting the random suffix after `.md`). Read the file before you write to it.

Suggest the skills to be used, if any, by the next session.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
