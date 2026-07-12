#!/usr/bin/env bash
#
# pocock-apply — the adopt-Pocock wrapper's GREENFIELD apply step.
#
# Consumes the deterministic plan emitted by `pocock-plan.sh` and, when the plan
# classifies the repo as *greenfield*, wires it to Matt Stone's standing Pocock
# suite: it creates the canonical `status:*` + orthogonal-facet labels, writes
# the `docs/agents/{domain,issue-tracker,triage-labels}.md` trio, adds the
# CLAUDE.md `## Agent skills` block, and writes an initial `pocock-stamp.md`.
#
# Scope (issue #51): GREENFIELD ONLY. Migrant upgrade and current patch are later
# tickets; on any non-greenfield plan this refuses and exits 3 rather than clobber
# a repo that already carries config. That refusal is also the idempotency guard —
# a second run sees a wired repo and stops.
#
# The apply is offline for the file artifacts. Label creation shells out to `gh`;
# override the command via `POCOCK_GH` (tests inject a recording shim) or pass
# --skip-labels to write the file artifacts without touching GitHub.
#
# Usage:
#   pocock-apply.sh [--root DIR] [--plan FILE] [--skip-labels]
#
#   --root DIR      repo root to wire (default: cwd)
#   --plan FILE     pre-emitted plan JSON; when omitted, apply runs pocock-plan.sh
#   --skip-labels   write file artifacts only; do not create GitHub labels
#
# Determinism knobs (tests):
#   POCOCK_GH                 label-creation command (default `gh`)
#   POCOCK_INSTALLED_VERSION  installed suite version recorded in the stamp
#   POCOCK_STAMP_DATE         `stamped` date (default: today, YYYY-MM-DD)
#   POCOCK_SUITE_DIR          installed suite root — when set, live role-binding
#                             (pocock-bind.sh, #53) discovers the tracker-role
#                             bindings and caches them into the stamp. Unset =>
#                             bindings deferred (written null) with a note.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$PWD"
PLAN_FILE=""
CREATE_LABELS=1
GH="${POCOCK_GH:-gh}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root)        ROOT="$2"; shift ;;
    --plan)        PLAN_FILE="$2"; shift ;;
    --skip-labels) CREATE_LABELS=0 ;;
    -h|--help)     sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

STAMP_VERSION="${POCOCK_INSTALLED_VERSION:-unknown}"
STAMP_DATE="${POCOCK_STAMP_DATE:-$(date +%F)}"

# ---- plan -----------------------------------------------------------------

# Consume the T1 plan — either a caller-supplied file or a fresh emission.
if [ -n "$PLAN_FILE" ]; then
  PLAN_JSON="$(cat "$PLAN_FILE")"
else
  PLAN_JSON="$(bash "$SCRIPT_DIR/pocock-plan.sh" --dry-run --json --root "$ROOT")"
fi

# Pull one scalar / array field out of the plan JSON (jq-free; python3 is already
# a suite dependency — see scripts/test/validate-skills.test.sh).
plan_field() { # key
  printf '%s' "$PLAN_JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin); v=d.get(sys.argv[1])
if isinstance(v,list):
    print("\n".join(str(x) for x in v))
elif v is None:
    pass
else:
    print(v)
' "$1"
}

FRESHNESS="$(plan_field freshness)"

# Greenfield-only guard. Anything else (migrant / current) is out of scope for
# this ticket and must not be clobbered — refuse loudly. This refusal is also the
# idempotency guard: a second run sees a wired repo and stops here.
if [ "$FRESHNESS" != "greenfield" ]; then
  echo "pocock-apply: only greenfield is supported here (plan freshness=$FRESHNESS); refusing to clobber existing config" >&2
  exit 3
fi

# Substrate + source-of-truth steer which pieces get written. A facts/ + sources/
# + refs/ corpus (source_of_truth=facts-corpus) is the artifact, not a GitHub
# tracker: skip the tracker-only docs (issue-tracker.md, triage-labels.md) and the
# label creation, and write a corpus-flavored CLAUDE.md block + a stamp recording
# substrate: trackerless-local with labels: []. The plan is the single authority —
# the emitter already dropped those artifacts/labels for a corpus; apply honors it.
SUBSTRATE="$(plan_field substrate)"
[ -n "$SUBSTRATE" ] || SUBSTRATE="tracker-backed"
SOT="$(printf '%s' "$PLAN_JSON" | python3 -c '
import json,sys
try:
    print(json.load(sys.stdin)["proposed_slots"]["source_of_truth"])
except Exception:
    pass
')"
CORPUS=0; [ "$SOT" = "facts-corpus" ] && CORPUS=1

echo "pocock-apply: greenfield — wiring $ROOT (substrate=$SUBSTRATE)"

# ---- 1. agent-doc trio (constant spine) -----------------------------------

mkdir -p "$ROOT/docs/agents"

# write_once RELPATH — heredoc on stdin; never clobber an existing file.
write_once() { # relpath
  local rel="$1" dest="$ROOT/$1"
  if [ -f "$dest" ]; then
    echo "  skip   $rel (exists)"
    cat >/dev/null
    return 0
  fi
  cat > "$dest"
  echo "  write  $rel"
}

write_once docs/agents/domain.md <<'EOF'
# Domain Docs

How the agent skills consume this repo's domain documentation when exploring the
codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root (if present) — the canonical glossary. Use
  its vocabulary in any output (issue titles, refactor proposals, test names).
- **`docs/adr/`** — architectural decision records that touch the area in play.
- **`docs/briefs/<name>.md`** — the brief for a current initiative carries the
  *why* and architecture. Created lazily; may not exist yet.

If any of these files don't exist, **proceed silently** — don't flag absence or
suggest creating them upfront. Producer skills create them lazily.

## Flag ADR conflicts

If output contradicts an existing ADR, surface it explicitly rather than silently
overriding — but only when the friction is real enough to warrant revisiting it.
EOF

# issue-tracker.md and triage-labels.md are tracker-only: they describe the GitHub
# Issues workflow and the status-label translation table. A trackerless-local corpus
# has no tracker, so skip both — writing them would force machinery that never runs.
if [ "$CORPUS" -ne 1 ]; then
write_once docs/agents/issue-tracker.md <<'EOF'
# Issue tracker: GitHub

Issues live as GitHub Issues, modeled on the nitimini workflow. Use the `gh` CLI
for all operations; PRDs/briefs live in `docs/briefs/`, not as issues.

## Three-level hierarchy

| Level | Artifact | Lives in |
|---|---|---|
| Roadmap | direction, themes | `README.md` (or `docs/product/ROADMAP.md`) |
| Brief / PRD | scoped initiative | `docs/briefs/<name>.md` + GitHub Milestone |
| Issue | vertical slice | GitHub Issue (flows the status state machine) |

Issue bodies must stand alone — an agent picks one up without reading back to the
brief. **PRDs are not issues.** `/to-spec` writes the document to
`docs/briefs/<name>.md` and stops; `/to-tickets` slices it into child issues.

## Conventions

- **Create**: `gh issue create --title "..." --body "..."` (heredoc for bodies).
  New issues open at `status: triage`.
- **Label**: `gh issue edit <n> --add-label "..."` / `--remove-label "..."`.
- **Close**: `gh issue close <n> --reason "completed|not planned"`.

## Branch and PR flow

**feature -> dev -> main.** Feature branches (`feat/*`, `fix/*`, `docs/*`) branch
off `dev` and PR into `dev` (the integration branch). `dev` PRs into `main` (the
release branch, GitHub default). Never commit straight to `main`.

## Kanban board & status

`status:*` labels are canonical; any Project board's Status field is a CI-derived
projection — set labels, never the field by hand. The board is a **flex point**,
never a requirement: the label vocabulary + state machine port everywhere; the
CI machinery does not. See [triage-labels.md](./triage-labels.md).
EOF

write_once docs/agents/triage-labels.md <<'EOF'
# Triage Labels

The agent skills speak in five canonical triage roles. This file is the
**translation table** mapping those roles onto this repo's board vocabulary. The
skills apply the mapping and never learn column names; divergence is free as long
as the mapping stays lossless.

## Canonical role -> board expression

| Canonical role (skills speak this) | Board expression (this repo) |
|---|---|
| `needs-triage` | `status: triage` |
| `needs-info` | `needs-info` (orthogonal facet) |
| `ready-for-agent` | `status: ready` **+** `afk` |
| `ready-for-human` | `status: ready` (no `afk`) |

The flag is `afk`, **not** `afk-ready` — don't re-smuggle "ready" into a
status-independent facet. `needs-info` is an orthogonal facet, not a seventh lane.

## Full label set

| Namespace | Label | Meaning |
|---|---|---|
| status | `status: triage` | New, needs scoping |
| status | `status: ready` | Spec'd, awaiting pickup |
| status | `status: wip` | Branch open, work started |
| status | `status: staged` | Merged to `dev` |
| status | `status: blocked` | Waiting on a dependency or decision (side state) |
| facet | `afk` | Tight enough for autonomous-agent pickup. Orthogonal to `status:*`. |
| facet | `needs-info` | Waiting on the reporter. Co-occurs with any status. |

`Released` is **label-less** (nitimini invariant): it is the issue's `closed`
state; where a board exists, `Status=Released` is the projection of closed.

## Status transitions

```
(new) -> status: triage
status: triage -> status: ready (scoped, AC written, deps clear) — add afk if tight enough
status: ready  -> status: wip   (branch opens off dev)
status: wip    <-> status: blocked
status: wip    -> status: staged (merged to dev)
status: staged -> (closed = Released) (dev -> main release)
```
EOF
fi

# ---- 2. CLAUDE.md `## Agent skills` block ---------------------------------

CLAUDE_MD="$ROOT/CLAUDE.md"
agent_block() {
  if [ "$CORPUS" -eq 1 ]; then
    # Trackerless corpus: no GitHub tracker block. The corpus IS the artifact.
    cat <<'EOF'
## Agent skills

### Corpus (source of truth)

No GitHub tracker. This repo is a `facts/ + sources/ + refs/` corpus — the corpus
is the artifact: `facts/` holds distilled claims, `sources/` the primary material,
`refs/` supporting references. Treat the corpus as the source of truth; there is no
issue tracker, no `status:*` labels, and no board/CI to wire.

### Domain docs

Glossary at `CONTEXT.md` (if present); briefs in `docs/briefs/` (lazy); ADRs in
`docs/adr/`. See [`docs/agents/domain.md`](./docs/agents/domain.md).
EOF
  else
    cat <<'EOF'
## Agent skills

### Issue tracker

GitHub Issues + Milestones. PRDs/briefs live in `docs/briefs/`, not as issues.
`feature -> dev -> main` flow (`dev` = integration, `main` = release + GitHub
default). See [`docs/agents/issue-tracker.md`](./docs/agents/issue-tracker.md).

### Triage labels

Nitimini-style `status:*` lifecycle vocabulary; `afk` and `needs-info` are
orthogonal facets. See [`docs/agents/triage-labels.md`](./docs/agents/triage-labels.md).

### Domain docs

Glossary at `CONTEXT.md` (if present); briefs in `docs/briefs/` (lazy); ADRs in
`docs/adr/`. See [`docs/agents/domain.md`](./docs/agents/domain.md).
EOF
  fi
}

if [ -f "$CLAUDE_MD" ] && grep -Fq "## Agent skills" "$CLAUDE_MD"; then
  echo "  skip   CLAUDE.md (## Agent skills present)"
elif [ -f "$CLAUDE_MD" ]; then
  { printf '\n'; agent_block; } >> "$CLAUDE_MD"
  echo "  write  CLAUDE.md (appended ## Agent skills)"
else
  { printf '# CLAUDE.md\n\n'; agent_block; } > "$CLAUDE_MD"
  echo "  write  CLAUDE.md (created with ## Agent skills)"
fi

# ---- 3. version stamp -----------------------------------------------------

# Live role-binding (#53): when an installed suite is available, discover the
# tracker-touching role bindings and cache them into the stamp as a per-version
# recipe. On the current suite this reproduces the static table (pure expand).
# On an ambiguous/empty bind the binder stops-and-surfaces (exit 4): we DO NOT
# guess — the stamp records `null` and the findings are echoed for the human.
# With no suite configured, bindings are simply deferred (null).
BIND=""
BIND_RC=0
BINDINGS_YAML="null"
if [ -n "${POCOCK_SUITE_DIR:-}" ]; then
  BIND="$(bash "$SCRIPT_DIR/pocock-bind.sh" --suite "$POCOCK_SUITE_DIR" \
            --version "$STAMP_VERSION" --format bindings-block 2>/tmp/pocock-bind.$$ )"
  BIND_RC=$?
  if [ "$BIND_RC" -eq 0 ] && [ -n "$BIND" ]; then
    BINDINGS_YAML="$(printf '\n%s' "$BIND")"
    echo "  bind   live role-binding: cached ${STAMP_VERSION} recipe into the stamp"
  else
    echo "  bind   live role-binding stopped-and-surfaced — bindings left null:" >&2
    sed 's/^/    /' /tmp/pocock-bind.$$ >&2
  fi
  rm -f /tmp/pocock-bind.$$
fi

# The stamp records the suite version + the STATIC translation table, plus the
# live-discovered `bindings` recipe (or null when deferred / surfaced). A
# trackerless-local corpus has no status labels / translation table, so its stamp
# records `substrate: trackerless-local` and `labels: []` instead — but it still
# carries the live-discovered `bindings` recipe (#53) when a suite is available.
if [ "$CORPUS" -eq 1 ]; then
  write_once docs/agents/pocock-stamp.md <<EOF
---
suite: matt-pocock-skills
version: $STAMP_VERSION
stamped: $STAMP_DATE
source: ~/.agents/skills
substrate: trackerless-local
freshness_applied: greenfield
bindings: $BINDINGS_YAML
labels: []
---

# Pocock stamp

Records the installed Matt Pocock suite version this repo was wired against, so a
later run can diff-audit for drift. Written by \`pocock-apply.sh\` on the greenfield
scaffold.

## Substrate: trackerless-local

This repo is a \`facts/ + sources/ + refs/\` corpus, not a GitHub tracker. No
\`status:\`-namespace labels, no translation table, and no board/CI were wired — the
corpus is the artifact and the source of truth. The live-discovered \`bindings:\`
recipe (#53) still applies when a suite is available; it is \`null\` when no suite
was configured or the binder stopped and surfaced an ambiguous/empty bind.
EOF
else
  write_once docs/agents/pocock-stamp.md <<EOF
---
suite: matt-pocock-skills
version: $STAMP_VERSION
stamped: $STAMP_DATE
source: ~/.agents/skills
freshness_applied: greenfield
bindings: $BINDINGS_YAML
labels:
  - "status: triage"
  - "status: ready"
  - "status: wip"
  - "status: staged"
  - "status: blocked"
  - "afk"
  - "needs-info"
---

# Pocock stamp

Records the installed Matt Pocock suite version this repo was wired against, so a
later run can diff-audit for drift. Written by \`pocock-apply.sh\` on the
greenfield scaffold.

## Translation table (static)

Canonical triage roles map onto this repo's board vocabulary. Skills apply the
mapping and never learn column names.

| Canonical role | Board expression |
|---|---|
| \`needs-triage\` | \`status: triage\` |
| \`needs-info\` | \`needs-info\` (orthogonal facet) |
| \`ready-for-agent\` | \`status: ready\` + \`afk\` |
| \`ready-for-human\` | \`status: ready\` (no \`afk\`) |

## Role bindings (live-discovered)

The \`bindings:\` frontmatter block above is the per-version role-binding recipe —
Matt's currently-installed skills bound to the tracker-touching abstract roles by
\`pocock-bind.sh\` (#53), discovered in authority order (release notes -> installed
SKILL.md -> ask-matt). On the current suite it reproduces the static table (pure
expand). It is \`null\` only when no suite was available or the binder stopped and
surfaced an ambiguous/empty bind for a human to resolve.
EOF
fi

# ---- 4. labels ------------------------------------------------------------

# Label creation is tracker-only. A trackerless corpus has no GitHub tracker, so the
# plan's labels_to_create is empty and there is nothing to create — say so and skip.
if [ "$CORPUS" -eq 1 ]; then
  echo "  labels skipped (trackerless-local corpus — no GitHub tracker)"
elif [ "$CREATE_LABELS" -eq 1 ]; then
  echo "  labels via '$GH':"
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    if "$GH" label create "$label" --force >/dev/null 2>&1; then
      echo "    + $label"
    else
      echo "    ! $label (gh label create failed — create by hand)"
    fi
  done < <(plan_field labels_to_create)
else
  echo "  labels skipped (--skip-labels); plan calls for:"
  plan_field labels_to_create | sed 's/^/    - /'
fi

echo "pocock-apply: greenfield wiring complete"
