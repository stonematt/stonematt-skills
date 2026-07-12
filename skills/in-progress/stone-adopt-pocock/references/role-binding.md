# Live role binding — model-discovered, never a slug table

A sub-step of the Stone delta ([`setup-and-delta.md`](./setup-and-delta.md), step
2b). You (the model) discover which **installed skill** currently fills each abstract
**tracker-touching role**, by *reading the installed suite live* — never from a
hardcoded slug table. A single skill rename in a suite bump must not silently break
Matt's config; that is exactly why the binding is discovered, not stored as a name
map.

The result is the `bindings:` block of the durable stamp
([`pocock-stamp.template.md`](./pocock-stamp.template.md)).

Spec: [`adopt-pocock-wrapper.md`](../../../../docs/briefs/adopt-pocock-wrapper.md) —
"Role binding is model-discovered live".

---

## Scope — tracker-touching roles ONLY

Bind **only** the roles that touch the tracker, and **only** those the installed
suite actually exposes. Do not invent a role the suite does not have, and do not bind
roles outside the tracker seam.

The tracker-touching roles to look for:

| Abstract role | What it does (the semantic contract you match against) |
|---|---|
| `on-ramp` | onboards a repo / brings a session up to speed on tracker state |
| `spec` | turns an idea into a spec / brief / PRD |
| `slice-to-tickets` | breaks a spec into tracked issues |
| `implement` | takes a ticket to an implementation / PR |
| `review` | reviews a change against spec + standards |
| `setup` | installs / reconciles the suite (Pocock's `setup-matt-pocock-skills`) |
| `wayfinder` | charts the map / frontier that feeds the tracker |

Bind the subset the installed suite exposes. If the suite exposes a tracker-touching
role not listed here, bind it too (the seam is "touches the tracker", not this exact
list); if it lacks one listed here, that role simply has no bind this version — note
it, do not fabricate one.

---

## Authority order (strict)

Resolve each role by consulting these sources **in this order**, stopping at the first
that gives an unambiguous answer:

1. **Release notes / changelog** — the suite's own record of what a skill was renamed
   *to* is the highest authority. A rename documented here resolves the bind directly.
2. **Installed `SKILL.md` text** — match the role's semantic *contract* (what the
   skill does), not its slug. The skill that documents doing the role's job fills the
   role, whatever it is now called.
3. **The `ask-matt` router** — the suite's own "which skill fills this role?" answer.
   Last resort, because it is a runtime query rather than a durable document, but it
   is authoritative when the first two are silent.

Record which source resolved each bind in the stamp (`via:`), so a later run can see
*how* the bind was reached, not just its value.

---

## Stop-and-surface — never guess

Two outcomes are **not** binds. On either, **halt and surface what you found** — do
not write a guessed bind into durable config that a later session will trust:

- **Ambiguous (split) bind** — two or more installed skills match the role's contract
  and the authority chain does not disambiguate. Surface all candidates.
- **Vanished (empty) bind** — no installed skill matches the role across all three
  authority sources. Surface the role and the fact that nothing fills it.

Surface concretely: name the role, the candidates (or the emptiness), and which
authority sources you consulted. Then stop the reconcile at that point — a durable
bind a future session trusts must never carry a guess.

---

## Forked commit/merge skills — FLAG, never auto-rewrite

If binding surfaces a **commit or merge skill that Matt has forked/customized**, do
**not** auto-rewrite the reference to point at the current suite skill, and do **not**
treat it as stale v1.0 prose to be rewritten (per `setup-and-delta.md` step 2c). Matt's
customization is a deliberate human call.

Flag it in the stamp (`forked:`) and surface it in the run report so Matt decides.
Rewriting his fork silently would clobber human-authored intent — the one thing the
reconcile must never do.

---

## Why live, not stored

The prior build hardcoded a v1.0→v1.1 slug table; one rename broke it, and its
"alternates" were literally the old names — overfit in code. Discovering the bind live
from the installed suite means the *next*, unseen bump costs nothing: the model
re-reads the changelog / `SKILL.md` / router and rebinds. On the current suite the
recipe simply reproduces the canonical roles (a pure expand, no drift) — which is what
a fresh stamp on an up-to-date suite looks like.
