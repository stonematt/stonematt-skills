# The executor is a facet of readiness, not a lane on the board

*A workflow-design note (authored by Matt Stone) from wiring Matt Pocock's engineering skills onto GitHub Issues. Captured as research input for map #31, ticket #43 (eligibility model). Source: `/tmp/pocock-kanban-preview.html`.*

I run the Pocock skills with GitHub Issues as the tracker, and I laid a real kanban over it: `triage → ready → wip → staged → Released`, with `blocked` as a side state. One design decision has paid off more than any other, and it's where I'd nudge the canonical model.

**The decision: who executes the work is orthogonal to where the work sits in flow.**

The skills speak in five canonical triage roles, two of which are `ready-for-agent` and `ready-for-human`. Modeled naively, those read as two columns — a "ready for an agent" lane and a "ready for a human" lane. I don't buy the second lane. There's **one** `ready` column on my board. Whether an issue is AFK-ready (an agent can pick it up cold) or needs a human is a *flag* on top of readiness, not a separate place: `status: ready` + `afk-ready`, versus `status: ready` alone.

Why this matters: executor is a property of the work item, not a position in the pipeline. The moment you make it a lane, you've doubled your board — every status forks into an agent variant and a human variant, and `status × executor` columns multiply for no gain. Keep it a facet and the board stays one clean flow dimension. You filter for "what can an agent pick up right now?" with a label query, not by hunting a column. In principle any status can carry the AFK/HITL character; it just earns its keep at `ready`, which is the handoff point.

There's a second decoupling underneath that makes it work: the skills' five roles are a **translation table** onto my board's richer vocabulary, not an identity. A skill that wants `ready-for-agent` applies my `status: ready` + `afk-ready` pair; it never has to know my column names. The canonical vocabulary and the board vocabulary stay independent, so I get a richer kanban without the skills fighting it.

Worth noting: v1.1 already leans this way. `/wayfinder` shipped its own orthogonal axis — `wayfinder:afk` vs `wayfinder:hitl` per ticket — scoped to wayfinder tickets. Same instinct, narrower scope. My suggestion is to generalize it: treat the human/agent executor as an orthogonal facet across the whole triage model, and resist shipping `ready-for-agent` / `ready-for-human` in a way that reads as two lanes. One ready state, one executor flag. A wayfinder ticket in my repo carries both axes at once — `status: ready` + `afk-ready` on the kanban axis, `wayfinder:research` + `wayfinder:afk` on the wayfinder axis — and different skills read different axes off the same issue without collision.
