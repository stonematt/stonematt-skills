# Genesis replay — the v1.1 upgrade + wayfinder session that started this project

*Reconstructed from Claude Code session transcripts of a real v1.1 upgrade in a **private** repo (nitimini). Research asset for map #31, ticket #45. Cross-checked against the dev's public Discord writeup ([`pocock-v11-friction-discord.md`](./pocock-v11-friction-discord.md), gist `540133c3677452e71a072c23875684a4`).*

> **Privacy note:** this is a public repo. Repo-private specifics from the source transcripts — internal issue/PR numbers, session ids, timestamps, and product/feature content — are intentionally omitted. Only the reusable, generalizable lesson is recorded here. If a full-detail forensic version is wanted, it belongs in the private repo, not this tree.

---

## (a) What happened (abstracted sequence)

1. **First `/wayfinder` run right after the v1.1 upgrade — but `/setup-matt-pocock-skills` was skipped.** The map built successfully anyway (the agent improvised, detecting the tracker heuristically). Mid-session the skipped setup was flagged; the agent diagnosed the missing config seam and hand-wrote `docs/agents/issue-tracker.md` from the setup skill's seed, shipping it via PR to `dev`.
2. **`/setup-matt-pocock-skills` then ran** — the deferred "wiring" step. It found the tracker doc present but **provisional / unreconciled** (plus a stale-mapping bug), and `triage-labels.md` + `domain.md` **missing**. It did the real reconciliation: bound the canonical role vocabulary to the repo's actual labels.
3. **`/wayfinder` continued cleanly** across later sessions once the tracker was wired.
4. **Later, reaching for the *next stage*, the wrapping layer still spoke v1.0** — "the project workflow didn't know `/to-spec` existed" — triggering a research-loop + `/ask-matt` rewrite pass (the wrapping-layer half; from the Discord source).

---

## (b) THE breakage — what "not wired up properly" concretely meant

**Not a symlink, install error, or broken skill.** The skills upgraded cleanly. What broke is the seam between the upgraded skills and *the repo's own configuration and wrapper prose*. Two concrete halves — transcripts nail the first, the Discord post nails the second.

### Half 1 — the config seam (transcript ground truth)

Running `/wayfinder` before `/setup-matt-pocock-skills` meant the repo was never told, in durable form, how it expresses the Pocock/Wayfinder mechanic:
- The agent had to **detect the tracker heuristically** and improvise rather than read a recipe.
- The wiring that should be durable was **"flying on in-context memory"** — living only in the current context window, gone next session.
- When setup ran, it surfaced the rest of the unwired state: the tracker doc existed only as a **"provisional, not reconciled" banner** with a **stale mapping bug**; `triage-labels.md` and `domain.md` were **missing**.
- **Root defect:** the skills speak a **canonical role vocabulary** (`ready-for-agent`, `ready-for-human`, `needs-triage`, `needs-info`) that was **never bound** to the repo's actual labels (`status:*` + `afk-ready` etc.). Nothing translated between the two vocabularies — a skill asking for "ready-for-agent" had no idea which label to apply.

The binding setup produced (the reusable schema #35 needs — label *conventions*, no private content):

| Canonical role (skills speak this) | Repo label (example mapping) | Note |
|---|---|---|
| `needs-triage` | `status: triage` | |
| `needs-info` | `status: blocked` | no true "waiting-on-reporter" state; blocked is closest |
| `ready-for-agent` | `status: ready` **+** `afk-ready` | `afk-ready` is **orthogonal** to `status:*`, not a column |
| `ready-for-human` | `status: ready` (no `afk-ready`) | |

Plus: `wayfinder:afk` / `wayfinder:hitl` is a **second, wayfinder-scoped** afk axis, distinct from the general `afk-ready` flag — both coexist.

### Half 2 — the wrapping-layer / command-map (Discord ground truth)

After the map, the *next stage* pointed at v1.0 skill names/shapes: **"the project workflow didn't know `/to-spec` existed."** Nothing scanned the repo for renamed/removed skills, so the first sign was a step that used to work not working. Stale surfaces: `WORKFLOW.md` (flowchart + command map), `CLAUDE.md`/`AGENTS.md` rules, forked commit/merge skills, custom `status:*` conventions, orchestration prose. Delta making them stale (breaking, no shim): `to-prd`→`to-spec`; `to-plan`+`to-issues`→`to-tickets` (`to-issues` deleted); `decision-mapping`→`wayfinder`; `review`→`code-review`; plus contract changes.

### The two halves are one lesson

**Upgrading a wrapped skills suite is a migration of your wrapping layer, not a swap of the skills** — with a config seam (Half 1) *and* a prose/command-map seam (Half 2). The transcript sequence confirms the ordering rule: **reconcile config first (`/setup-matt-pocock-skills`), then audit the wrapping layer.** Audit-only misses the config seam entirely.

---

## (c) Friction / dead-ends a wrapper could have prevented

- **No preflight gate.** `/wayfinder` ran happily on an un-setup repo and *built a real map*. It never checked "is this repo wired for the current skill version?" Success was luck (improvised tracker doc). A wrapper should refuse or warn when `docs/agents/issue-tracker.md` is absent or provisional.
- **Silent seed identity-mapping trap.** The setup seed defaults to an **identity** label map (`needs-triage`→`needs-triage`). That is **wrong for this user's fleet** — the repos use `status:*` + `afk-ready`, not the canonical names. A naive migration that accepts seed defaults mis-maps silently across the whole fleet.
- **Provisional/partial-run state.** A prior partial run left the tracker doc half-written with a banner and a stale bug. Re-running had to *detect and reconcile* that state, not clobber or trust it.
- **"Flying on in-context memory."** Missing durable docs meant correctness lived only in the current session and would not survive to the next skill run.
- **The outlier problem.** Only one repo has `wayfinder:*` labels + custom kanban; others are pre-Wayfinder. The bespoke wayfinder section must **not** be carried to other repos, but the `status:*` label mapping **must**.
- **Discovery-after-the-fact.** Wrapping-layer staleness only surfaced when a downstream step failed — the most expensive place to find it.

---

## (d) Concrete implications for the map's tickets

### #35 — role-binding
Setup's reconciliation **is** the reference implementation: bind canonical roles → repo's real labels. Non-obvious rules to encode:
- A role can map to a **label pair** (`ready-for-agent` = `status: ready` **+** `afk-ready`), not just one label; `afk-ready` is orthogonal to `status:*`.
- `wayfinder:afk`/`wayfinder:hitl` is a **separate axis** — binding must allow two coexisting afk systems.
- The seed's **identity** default is the wrong baseline for this fleet — role-binding must force an explicit per-repo map, never accept identity silently.

### #36 — state-detection / migrant
A migrant/state-detector must handle:
- **Partial prior runs**: file present but carrying a "provisional, not reconciled" banner → reconcile, don't clobber.
- **Stale mappings**: detect drift against live `gh` labels.
- **Missing siblings**: `triage-labels.md`/`domain.md` absent while `issue-tracker.md` exists → partial state is normal.
- **Outlier split**: carry the portable `status:*` mapping to other repos but **drop** the local wayfinder section.
- **Two-half scope:** the migrant is **both** "setup-reconcile the config seam" **and** "full stale-ref + contract rewrite of the wrapping layer" — in that order.

### #39 — spec
Core requirement falls straight out of the genesis: a **preflight wiring check** before any Pocock skill (especially `/wayfinder`) does real work.
- Detect: does `docs/agents/issue-tracker.md` exist and is it reconciled (no provisional banner)? Are canonical roles bound? Are `triage-labels.md`/`domain.md` present? Any stale references to renamed/removed v1.0 skills?
- On miss: run/prompt `/setup-matt-pocock-skills` **first**, then audit the wrapping layer — never audit-only.
- Give setup an **upgrade mode**: on re-run after a version bump, scan for stale skill references + contract mismatches and flag them (the dev's product ask; consistent with the map's wrap-not-fork decision).
- Treat "the map built successfully" as **not** proof of correct wiring.

---

## New fog surfaced

- **Wrapper preflight is a hard requirement, not a nicety** (feeds #39): `/wayfinder` will silently run on an unwired repo and *appear* to succeed. The wrapper needs an explicit "is this repo wired for the current version?" gate — possibly its own ticket.
- **Fleet migration split** (feeds #36): portable `status:*` mapping vs. local wayfinder section is a concrete design constraint for the migration prompt; worth its own decision ticket if not already covered.
