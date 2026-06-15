---
name: stone-client-report
description: Generate an executive-level client summary of product changes since a given date. Use when the user says /stone-client-report, "summarize for the client", "executive summary", "session report", "client update", "what did we deliver since [date]", or wants to roll up dev work into business-value terms for stakeholder communication. Also trigger when the user mentions preparing for a client meeting, writing a deliverables recap, or reconciling work against an SOW.
---

# Client Report Skill

Generate a business-executive-level summary of product changes over a date range. The output focuses on *why changes matter* and *what value was delivered*, not on tactical commit details. Organized around business topics that map to client priorities, not git history.

## Workflow

### 1. Determine the date range

Ask the user for the start date if not provided. Common patterns:
- "since February" → `--since=2026-02-01`
- "last month" → calculate from today
- "since the last session" → ask for clarification

### 2. Locate the SOW

Search for a Statement of Work in the project and parent directories:
- Look for files matching `*sow*`, `*statement*of*work*`, `*scope*` (case-insensitive) in the repo root, `docs/`, and parent directories up to 3 levels
- Also check `~/Documents/` and `~/Desktop/` for obvious matches
- If found, read it and extract deliverable line items to use as an organizing frame
- **If not found, ask the user**: "I don't see a Statement of Work in the project. Do you have one I should reference? If so, give me the path. If not, I'll organize around the themes I find in the work."

### 3. Gather inputs

Run in parallel:
- `git log --since=<date> --format="%h %ad %s" --date=short` (all commits in range)
- `git log --since=<date> --format="%h %s" --no-merges` (non-merge commits for analysis)
- `git log --since=<date> --merges --format="%h %s"` (merge commits to identify PR boundaries)
- Read the dev journal file (check auto-memory at the project memory path for `dev-journal.md`)
- Read `docs/changelog/README.md` if it exists
- Read `docs/roadmap/README.md` if it exists
- Scan `docs/roadmap/` for any planning/proposal documents created or modified in the date range

### 4. Identify roadmap and future-work documents

Read each roadmap document found. For items marked "Planned", "Not Scheduled", or "Future Considerations", note them as potential future projects. These are important to the user because they may become follow-on engagements or SOW amendments.

### 5. Synthesize the report

This is the core of the skill. Transform raw development activity into business-value language.

**Organizing principle**: Group by business topic, not by date or artifact type. Good topic groupings emerge from the work itself but commonly include:
- Dashboard capabilities delivered (what users can now do)
- Data quality and accuracy improvements
- Performance and reliability gains
- User experience and navigation improvements
- Session/event readiness
- Training and enablement

If an SOW was found, use its deliverable categories as the primary organizing frame, then add sections for work that falls outside the SOW scope.

**Voice and framing**:
- Write for a business executive who cares about outcomes, not implementation
- Lead each section with what the *user* (coordinator, team lead) can now do or see
- Translate technical work into business language: "pre-aggregate optimization" becomes "dashboard load times reduced from 15+ seconds to 2-3 seconds"
- Quantify where possible: number of dashboards delivered, metrics added, performance gains
- Avoid jargon: no "AML", "pre-agg", "model measures", "dataset refs" — use "analytics views", "performance optimization", "data metrics"
- Keep it scannable: short paragraphs, bold key points, bullet lists for deliverables

**What to include**:
- Delivered capabilities and their value to end users
- Significant data quality or accuracy fixes (framed as "improved reliability of X metric")
- Performance improvements with before/after impact
- Training materials or documentation produced (especially out-of-band work from dev journal)
- Architecture decisions that set up future capabilities

**What to exclude**:
- Internal tooling changes (CI, linting, editor config)
- Code refactors that don't change user-facing behavior (unless they enable future features — in that case, frame as "foundation for...")
- Commit-level detail, file names, branch names
- Developer process changes

### 6. Add the future opportunities section

This section is strategically important — it surfaces follow-on work.

For each roadmap/planning document produced during the period:
- Summarize the problem it addresses in business terms
- State the proposed approach at a high level
- Note the expected benefit
- Flag it as a potential future project or SOW item

Also include any "Next" items from the dev journal that represent substantive future work (not just cleanup tasks).

Frame this section as "Recommended Next Steps" or "Future Opportunities" — language that invites discussion without committing to scope.

### 7. Write the output file

**Output path**: `docs/client-reports/<YYYY-MM>_executive-summary.md`

Create the `docs/client-reports/` directory if it doesn't exist.

If the date range spans multiple months, use the end month for the filename (e.g., work from Feb 1 to Mar 6 → `2026-03_executive-summary.md`).

**Document structure**:

```markdown
# Executive Summary: [Product Name] — [Date Range Description]

**Prepared for:** [Client name from CLAUDE.md or ask]
**Prepared by:** [From docs/roadmap/README.md contact info or ask]
**Period:** [Start date] — [End date]

---

## Overview

[2-3 sentence high-level summary of what was accomplished and the overall trajectory. Frame in terms of value delivered.]

## [Business Topic 1]

[What users can now do. Why it matters. Key deliverables as bullets.]

## [Business Topic 2]

[...]

## Performance and Reliability

[If applicable — quantified improvements]

## Training and Enablement

[If applicable — materials produced, sessions conducted]

## SOW Reconciliation

[If SOW was provided — map delivered work to SOW line items. Note items complete, in progress, or not yet started. This section helps the client see progress against contracted scope.]

## Recommended Next Steps

[Future opportunities identified during this period. Each with a brief business case. These are conversation starters for scope expansion or follow-on work.]

---

*This summary covers development activity from [date range]. Detailed technical records are maintained in the project changelog and dev journal.*
```

### 8. Present for review

Show the full report to the user in a fenced markdown block so they can review before it's written to disk. The user will likely want to:
- Adjust tone or emphasis
- Add context about out-of-band work not captured in git
- Remove items that aren't relevant to this client
- Add SOW reconciliation details

After approval, write the file. Ask if they want a commit:
```
docs: add executive summary for [date range]
```

## Style Guide

- **Tone**: Professional, concise, confident. Write like a consultant summarizing deliverables, not like a developer explaining code.
- **Length**: Aim for 1-2 pages when rendered. Executives skim — every sentence should earn its place.
- **Numbers**: Quantify wherever possible. "5 new analytics views" not "several new dashboards".
- **Attribution**: Credit the team/engagement, not individual contributors or tools.
- **Jargon**: Zero technical jargon. If you catch yourself writing a term the client's VP wouldn't understand, rewrite it.
- **Active voice**: "Coordinators can now compare team performance across events" not "A cross-event comparison feature was implemented".

## Notes

- The dev journal is the richest input — it captures intent, out-of-band work, and next steps that git history misses. Prioritize it over raw commit logs.
- Merge PR titles often contain good one-line summaries of feature bundles.
- The user treats this output as raw material they'll integrate with other artifacts. Make sections self-contained so they can be excerpted or rearranged.
