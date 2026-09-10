# Thin Orchestrator — Spec

Make the mechanical ticket loop — triage → implement → review → commit → merge —
run under a session that holds **pointers, not content**, so it never needs a
`/handoff` to keep going. The human's role in that loop is orchestration: tag
the work, answer the questions a lane genuinely cannot, and nothing else.

Extends `/swarm` (`skills/in-progress/swarm/`). Swarm already has the right
shape — one fresh context per ticket, merges held by the main session — but it
leaks its own bookkeeping into the orchestrator, has no single-issue entry, and
went unused in the window below.

**Not in scope:** judgment work. Grilling, interviews, design rounds, wayfinder
and to-spec keep their `/clear` + `/handoff` cadence unchanged; for them, that
cadence is part of the method.

## Problem Statement

Transcript analysis of roughly 20 sessions over four days in one private app
repo turned up 12 handoffs. Peak context per session ran from 100k to 424k, and
nothing ever compacted. The handoffs came at phase boundaries, not at a hard
ceiling.

Delegation already works: the orchestrator never watched CI or read a full
diff itself. One session turned a single instruction into 17 subagents and 8
merged PRs. Another took an issue from triage to merge on three typed human
turns ("triage N", "/implement N", "push pr code-review merge").

**The harness is already doing the work. The human is doing the context resets.**

One session drove four issues end to end over about 14 hours and peaked at
424k. That is roughly 100k of orchestrator context per issue, even though
subagents did every build, review and CI watch. (This is session total divided
by issues, not a per-issue measurement.)

### 1. Orienting reads land in the main context

What filled the orchestrator was its own orientation, not the work:

| Consumer | Size per occurrence | Pattern |
|---|---|---|
| `gh issue view` on a batch of issues | 13–14k chars | read once per session |
| Runbook / status docs | 5–13k chars each | re-read in 4+ consecutive sessions |
| The previous session's handoff doc, via `cat` | 7–11k chars | every session that continued from a handoff |
| `SKILL.md` bodies via `cat` (wayfinder, triage) | 6.5–10k chars | instead of the `Skill` tool or a subagent |
| `stone-merge` `SKILL.md` | 378 lines | loaded again on every merge |
| Swarm profile pasted into each lane brief | ~210 lines | emitted by the orchestrator once per lane |

None of it needs the orchestrator's reasoning. This is exactly the "noisy
investigation" class the global routing rule says to delegate. It stays inline
because each item is a single cheap-looking Bash call the orchestrator makes to
orient itself before it dispatches.

### 2. The reset is manual

The process says each ticket starts in a fresh context. In practice, a fresh
context means a new session, reached through `/handoff`.

`/handoff` writes free-form markdown to the OS temp directory. It has no fixed
path, no index and no reader. So the human pastes the path, and the next
session `cat`s the whole document back in. Every reset costs a human turn plus
7–11k tokens of restated state. Most of that state already lives in the
tracker as labels, PRs and merge SHAs.

### 3. `/swarm` is the right shape, but it leaks and it is unused

A swarm lane is exactly a fresh context per ticket. But the orchestrator side
does the heavy reading itself:

| Swarm step | What the orchestrator does inline |
|---|---|
| 1, Build the queue | reads every open issue, including bodies and comments |
| 2, Fence the lanes | maps each issue to the code it will touch |
| 3, Pin the profile | runs the gates and the blast-radius probe |
| 4, Launch | pastes the full profile into each lane brief |
| 5, Verify | runs the gates and reads the tree |
| Salvage | runs `git status` and `git diff` in the stalled lane's worktree |

Swarm is also built for a batch queue. The common case is one or two issues
arriving from triage, and swarm has neither a triage step nor a single-issue
entry. It was invoked zero times across every repo in the window.

### 4. Nothing claims an issue

Two windows ran the same triage → implement → merge sequence on the same issue
at the same time, for about 50 minutes. That is duplicate spend plus a merge
race. The lane brief never sets `status: wip`, and nothing checks it before
work starts.

### 5. Drift makes lanes stop and ask

- **Stale profile.** The repo's committed swarm profile said `CONTEXT.md` and
  `docs/adr/` did not exist. Both did.
- **Contradictory landing rules.** The repo's lifecycle doc and `stone-commit` /
  `stone-merge` disagreed on closing-keyword behavior on `dev` and on whether
  `--match-head-commit` is required.

Each contradiction is a place where a lane either stops for a human or guesses.

## Proposed Design

### Principle: pointers, not content

The tracker is the state. The orchestrator's context per ticket should be four
things, and nothing else:

1. **The dispatch brief.**
2. **The lane's readiness report.**
3. **An independent verifier's verdict** — see B. A lane report is a claim
   (`swarm/SKILL.md:64`), and "pointers, not content" must not collapse
   verification into trusting it.
4. **The merge call**, plus the lane's one-line cleanup acknowledgement.

**Target: at most about 5k orchestrator tokens per ticket.** At that rate a 1M
window holds a full queue, and `/handoff` disappears from mechanical mode.

Working rule: **the orchestrator never runs a command whose output it did not
ask to have summarized.** Where it needs a fact, a subagent fetches the fact.

**What the budget has to cover:**

| Item | Estimate / constraint |
|---|---|
| Dispatch brief | ~1.5–2k output tokens, including the run's inline gate baseline |
| Lane exchanges | Two per ticket: the readiness report at merge time (`LANE-BRIEF.md:61`) and a one-line ack after cleanup |
| `needs-human` text | One question, at most two lines |
| Task-list bookkeeping (`swarm/SKILL.md:56`) | One status update per ticket |
| The merge | Must not load the 378-line `stone-merge` body — **#103 is a prerequisite** |

### A. Ticket lanes: an explicit-issue entry to `/swarm`

`/swarm <n> [<n> …]` takes explicit issues and gives each one a lane of width 1.

- **Fencing.** An explicit list is fenced exactly like the batch queue. Lanes
  run in parallel where step 2 proves their file sets disjoint, and serially
  where they collide. Step 2 is already a subagent (B), so the disjointness
  proof costs the orchestrator nothing.
- **Bare `/swarm`.** Keeps today's behavior: build the queue from the `afk` set.

**Step 0: claim, then triage.** The lane brief gains a step 0, run before the
lane loads anything else:

1. Claim the issue (C).
2. Dispatch a Sonnet triage subagent, so that an early stop costs a
   near-empty lane context. It applies the finish-alone test
   (`swarm/SKILL.md:12–14`) from inside the lane, and checks sub-issues and
   `blocked_by` links. That second check matters: a lane that reads only its
   own issue cannot otherwise see that its issue is the umbrella over others
   in the queue, and would "finish" it by doing every child in one PR,
   colliding with the lanes working those children.
3. If the triage subagent reports the issue is an umbrella, stop with
   `stopped: umbrella`. If it cannot reach agent-ready without a human, stop
   with `needs-human` and a single question.

**The orchestrator never reads the issue body.**

**Report contract.** The readiness report is fixed-shape and capped at about
15 lines:

```
issue: #<n>   status: ready-to-merge | needs-human | stopped[: claimed | umbrella | fence | red-gate]
pr: #<m>      base: <sha>   head: <sha>
gates: <gate> <pass>/<total> · <gate> <pass>/<total> · …
review: standards <clean | fixed k> · spec <clean | fixed k>
design call: <one line, or none>
needs human: <one question, ≤2 lines, or none>
held findings: <k> — listed in PR body
merge: <verbatim gh pr merge command, including --match-head-commit <head sha>>
```

- **`base`** is carried so the orchestrator can hand it to the verifier without
  reading anything.
- **`merge`** is the output of `stone-merge`'s `merge-cmd.sh` (#103), reported
  verbatim. `--match-head-commit` stops the orchestrator merging a head that
  moved after the verifier ran.

**Held findings go in the PR body, and the lane never files them.** A lane saw
the code through its fence and may have a finding half right, which is why
swarm step 6 re-checks each one against the code before filing
(`swarm/SKILL.md:76`). The lane lists findings in its PR body and reports only
a count. The end-of-run filer (B) reads them all and does the re-check.

**The profile is passed by path, with the run's gate baseline inline.** The
brief tells the lane to read `.claude/swarm-profile.md` at `<baseline sha>` for
docs, verbs, unrun scripts and landing policy. The lane runs in a fresh
context, so the read costs it nothing extra, and the orchestrator no longer
emits 210 lines per lane.

Gate numbers and the blast-radius probe belong to the run, not the repo
(`swarm/PROFILE.md:5`), so a committed profile's gate rows are stale by
construction. The brief carries this run's gate baseline inline, in two lines.

### B. Move the orchestrator's reads into subagents

Each swarm step whose output is bulky becomes a Sonnet subagent that returns a
table or a verdict.

| Step | Subagent reads | Subagent returns |
|---|---|---|
| 1, Queue | issue bodies and links | an in/out table, with a one-line reason for each issue |
| 2, Fence | **issue bodies and the code**, not titles, and not whatever handoff sent you here (`swarm/SKILL.md:20`) | a lane table: issue → files → collisions |
| 3, Profile + baseline | the repo, the committed profile, and a gate run | gate numbers at a named commit, blast-radius survivors, and a **drift verdict**: `launch` \| `fix-profile-first` \| `red-baseline` |
| 5a, Verify per ticket (**before** each merge) | the PR branch at `head`, against `base` | two lines: gates at `<sha>`, and whether the tree is clean |
| 5b, Verify at end of run | the merged base | gate numbers; any leftover branches, worktrees or open PRs |
| 6, Findings | every merged PR body's held findings, plus `git grep <symbol> <baseline>` | a table: **debris** (this run introduced it → cleanup lane) / **pre-existing** (→ ticket, combined by theme) / **decline** (with reason) |
| Salvage | the stalled lane's worktree | a state summary, a proposed resume point, and **the lane's agent id**, since the orchestrator resumes a lane with `SendMessage`, which needs the id |

The drift verdict exists because a bare drift table leaves the orchestrator
unable to judge whether the drift is fatal without reading the repo itself.

Step 6 keeps swarm's two-pile sort (`swarm/SKILL.md:72–76`), which a lane-side
report could not carry.

The orchestrator keeps:

- the lane and fence decision
- the per-lane model choice
- every `gh pr merge` (the classifier constraint is unchanged)
- dispatching the cleanup lane from the step-6 table
- relaying escalations to the human

### C. Claim lock

Claiming is step 0.1 of every lane:

1. **Read.** Read the issue's labels and its claim comments.
2. **Stop if claimed.** If a live claim exists, stop with `stopped: claimed`.
3. **Claim.** Otherwise, post a claim comment carrying the lane id and a
   timestamp. Swap `status: ready` for `status: wip` — per
   `triage-labels.md:45`, the claim replaces the ready label rather than adding
   a second `status:` label. Then self-assign.
4. **Re-read, earliest wins.** Re-read the claim comments. If an earlier claim
   exists, withdraw yours and stop with `stopped: claimed`. This closes the
   check-then-set race without needing an atomic primitive.

**Stale claims are reclaimable.** A claim is stale when there is no linked PR
and no lane activity on the issue for N hours. The reclaiming lane comments
that it is taking over before it claims.

Without this rule, every lane that crashes leaves its issue stranded under
`status: wip` until a human unlabels it.

### D. Queue driver (phase 2)

A `/loop` in the main session, dynamic pacing, over the `afk` queue. Each wake:

1. For any lane that reported `ready-to-merge`: dispatch the per-ticket
   verifier (5a), and merge on a clean verdict.
2. Dispatch the next unblocked, unclaimed `afk` issue.
3. Push a notification for each `needs-human` or `stopped`.

The labels are the steering surface:

- **`afk`** means the harness owns the issue end to end.
- **No `afk`** means the lane stops at `needs-human` rather than guessing.

Lane completions already wake the orchestrator, so the loop's own wake is only
a fallback heartbeat. This phase waits until A–C are piloted.

### E. A handoff with a reader, for judgment work

This is a hook-only change; the upstream `/handoff` skill is untouched.

- **Hook, not body.** A `SessionStart` hook finds the newest handoff and
  prints its path plus its first three lines (the gist), never the body.
- **Locating it.** Either by a known location the user sets once, or by
  searching the temp directory for the newest handoff-shaped file. Which one
  is the implementation's call.
- **Pointers first.** The habit that pays off is leading a handoff with tracker
  pointers (issues, PRs, SHAs) rather than restating what they already say.

## Scope

0. **Prerequisite: #103** — split `stone-merge` into a thin `SKILL.md` for the
   main session plus a subagent runbook and scripts. Its `merge-cmd.sh`,
   `ready.sh`, `watch.sh` and `cleanup.sh` are reused by the lanes and the
   per-ticket verifier.
1. **Explicit-issue entry, step-0 claim + Sonnet triage, report contract,
   profile-by-path with inline gate baseline, PR-body findings.**
   Files: `swarm/SKILL.md`, `swarm/LANE-BRIEF.md`.
2. **Move swarm steps 1, 2, 3, 5 (split into 5a and 5b), 6 and salvage into
   subagents**, including the drift verdict and the per-ticket verifier.
   File: `swarm/SKILL.md`.
3. **Claim lock**, with earliest-wins and stale reclaim.
   File: `swarm/LANE-BRIEF.md` step 0.
4. **Handoff `SessionStart` reader hook.**
5. **Queue driver** (phase 2, after items 1–3 are piloted).

**Pilot and measure.** Run items 1–3 on the next `afk` issue in a real repo.

- **Orchestrator cost per ticket.** Read it from the transcript's `usage`
  fields: the context delta between dispatch and merge. Target: ≤5k. Record
  the dispatch brief's size separately, since that is the item most likely to
  blow the budget.
- **Human turns per `afk` ticket.** Target: one, the trigger.

## Resolved in review

An adversarial review settled these:

- **Held findings** live in the PR body. An end-of-run Sonnet filer re-checks
  and files them, so swarm's re-check against the code survives.
- **Claim atomicity** comes from the earliest-wins claim comment. The same
  comment is needed anyway for stale-claim recovery.
- **Triage** stays in the lane, run as the lane's own Sonnet subagent before
  the lane loads anything.
- **Explicit issue lists** are fenced like the batch queue, not serial by default.
- **Handoff delivery** is hook-only.

## Open Questions

- **Stale-claim threshold.** What is N hours? It has to exceed the longest
  plausible lane (gates plus CI on a slow repo), or a live lane gets reclaimed.
- **Verifier duplication.** The per-ticket verifier re-runs gates the lane has
  just run. Is there a cheaper independent check — say, CI status at
  `head` plus a tree-clean probe — that keeps "a report is a claim" without a
  second full gate run?
- **Is the 5k target real?** Measure it in the pilot. If the brief plus two
  exchanges plus the verdict already sits near 4k, the target needs revising
  rather than the design.

## Out of Scope

- The judgment-mode flows (grilling, interviews, wayfinder, to-spec,
  to-tickets) and their `/clear` + `/handoff` cadence.
- Merge authority. `gh pr merge` stays in the main session.
- Model-routing policy, and any cap on spend, depth or fan-out.
- Fixing the private repo's profile and lifecycle-doc drift itself. This
  brief adds the check that catches such drift; the repo fixes its own docs.
