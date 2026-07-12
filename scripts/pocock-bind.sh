#!/usr/bin/env bash
#
# pocock-bind — the adopt-Pocock wrapper's LIVE role-binding seam (issue #53).
#
# Replaces the static role->skill table with discovery from the *installed*
# suite at run time. For each tracker-touching role, it binds the skill that
# currently fills that role, consulting sources in strict order of authority:
#
#   1. release notes / changelog  — a bump usually announces a split/merge/rename.
#   2. installed SKILL.md text     — the skill still present under a known slug.
#   3. ask-matt                    — the router skill answers "which skill fills
#                                    this role" when 1-2 are ambiguous or empty.
#
# Guardrails (brief: docs/briefs/adopt-pocock-wrapper.md, "Role-binding contract"):
#   - narrow scope: only the tracker-touching roles are bound.
#   - stop-and-surface: an ambiguous (split) or empty (vanished) bind is NOT
#     auto-resolved — the seam exits 4 and prints findings so a human decides.
#     Durable config later sessions trust must never carry a guessed bind.
#   - forked commit/merge skills are FLAGGED, never auto-rewritten — a human call.
#
# The discovered bindings + a version delta are emitted as a per-version recipe,
# cached into docs/agents/pocock-stamp.md by pocock-apply.sh.
#
# Usage:
#   pocock-bind.sh --suite DIR [--version V] [--prior-version V] [--format FMT]
#
#   --suite DIR        installed suite root (default: $POCOCK_SUITE_DIR). Holds
#                      one <skill>/SKILL.md per installed skill; optionally a
#                      release-notes.md and an ask-matt/role-map.txt.
#   --version V        installed suite version (default: $POCOCK_INSTALLED_VERSION,
#                      else a VERSION file in the suite, else "unknown").
#   --prior-version V  the version the repo was last stamped against, for the
#                      version delta (default: $POCOCK_PRIOR_VERSION, else none).
#   --format FMT       recipe (default: full YAML recipe) |
#                      bindings-block (just the indented `bindings:` map, for the
#                      stamp) | delta (just the version-delta line).
#
# Exit codes: 0 all roles resolved · 2 usage · 3 no suite · 4 stop-and-surface.

set -uo pipefail

SUITE="${POCOCK_SUITE_DIR:-}"
VERSION="${POCOCK_INSTALLED_VERSION:-}"
PRIOR="${POCOCK_PRIOR_VERSION:-}"
FORMAT="recipe"

while [ $# -gt 0 ]; do
  case "$1" in
    --suite)         SUITE="$2"; shift ;;
    --version)       VERSION="$2"; shift ;;
    --prior-version) PRIOR="$2"; shift ;;
    --format)        FORMAT="$2"; shift ;;
    -h|--help)       sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ -z "$SUITE" ] || [ ! -d "$SUITE" ]; then
  echo "pocock-bind: no installed suite at '${SUITE:-<unset>}' (--suite / \$POCOCK_SUITE_DIR)" >&2
  exit 3
fi

if [ -z "$VERSION" ]; then
  if [ -f "$SUITE/VERSION" ]; then
    VERSION="$(head -1 "$SUITE/VERSION" | tr -d '[:space:]')"
  else
    VERSION="unknown"
  fi
fi

# ---- role contracts (narrow: tracker-touching only) ------------------------
#
# Each role lists the installed-skill slugs that satisfy its contract. The FIRST
# slug is the canonical current-suite skill; the alternates are plausible
# variant/legacy names so a rename or split is *detectable* (a role matching two
# installed skills is ambiguous; matching none is empty — both stop-and-surface).
# On the current suite exactly one slug per role is installed => a clean bind
# that reproduces the static table (pure expand — no behavior change).

ROLES="on-ramp spec slice-to-tickets implement review setup wayfinder"

role_slugs() { # role -> accepted skill slugs (space-separated)
  case "$1" in
    on-ramp)          echo "wayfinder" ;;
    spec)             echo "to-spec spec" ;;
    slice-to-tickets) echo "to-tickets to-issues" ;;
    implement)        echo "implement" ;;
    review)           echo "code-review review" ;;
    setup)            echo "setup-matt-pocock-skills setup-pocock" ;;
    wayfinder)        echo "wayfinder" ;;
    *)                echo "" ;;
  esac
}

# ---- suite probes ----------------------------------------------------------

# A skill is "installed" iff <suite>/<slug>/SKILL.md exists (authority 2 reads it).
skill_installed() { [ -f "$SUITE/$1/SKILL.md" ]; }

# Authority 1 — release notes. Lines of the form `bind <role> <skill>` in a
# release-notes.md / CHANGELOG.md explicitly announce a role's new home.
release_note_bind() { # role -> skill or empty
  local role="$1" f
  for f in release-notes.md RELEASE-NOTES.md CHANGELOG.md; do
    [ -f "$SUITE/$f" ] || continue
    awk -v r="$role" '
      $1=="bind" && $2==r { print $3; found=1; exit }
      END { exit(found?0:1) }
    ' "$SUITE/$f" && return 0
  done
  return 1
}

# Authority 3 — ask-matt. The router skill ships a role-map answering
# "which skill fills <role>". Lines: `<role> <skill>`.
ask_matt_bind() { # role -> skill or empty
  local role="$1" f="$SUITE/ask-matt/role-map.txt"
  [ -f "$f" ] || return 1
  awk -v r="$role" '$1==r { print $2; found=1; exit } END { exit(found?0:1) }' "$f"
}

# ---- forked commit/merge guardrail -----------------------------------------
# Flag (never bind, never rewrite) any installed commit/merge skill that looks
# forked: a `fork-of:` frontmatter marker or a `stone-`-prefixed slug shadowing
# a Pocock commit/merge verb. These stay a human call.

forked_flags() {
  local d name
  for d in "$SUITE"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    name="$(basename "$d")"
    case "$name" in
      *commit*|*merge*) : ;;
      *) continue ;;
    esac
    if grep -qiE '^fork-of:' "${d}SKILL.md" 2>/dev/null || case "$name" in stone-*) true ;; *) false ;; esac; then
      echo "$name"
    fi
  done | sort -u
}

# ---- discovery -------------------------------------------------------------
# For a role: authority 1 (release notes) wins outright; else authority 2
# (installed SKILL.md by contract slug) if it resolves to exactly one skill;
# else authority 3 (ask-matt). Zero or many candidates with no higher authority
# => UNRESOLVED, tagged empty|ambiguous, for stop-and-surface.

declare -a BIND_ROLE=() BIND_SKILL=() BIND_SOURCE=()
declare -a UNRESOLVED=()

discover() {
  local role slug rn cands n am
  for role in $ROLES; do
    # authority 1: release notes
    if rn="$(release_note_bind "$role")" && [ -n "$rn" ]; then
      if skill_installed "$rn"; then
        BIND_ROLE+=("$role"); BIND_SKILL+=("$rn"); BIND_SOURCE+=("release-notes")
        continue
      else
        UNRESOLVED+=("$role|release-note names '$rn' but it is not installed")
        continue
      fi
    fi

    # authority 2: installed SKILL.md, matched by contract slug
    cands=()
    for slug in $(role_slugs "$role"); do
      skill_installed "$slug" && cands+=("$slug")
    done
    n="${#cands[@]}"
    if [ "$n" -eq 1 ]; then
      BIND_ROLE+=("$role"); BIND_SKILL+=("${cands[0]}"); BIND_SOURCE+=("skill-md")
      continue
    fi

    # authority 3: ask-matt disambiguates empty or ambiguous
    if am="$(ask_matt_bind "$role")" && [ -n "$am" ] && skill_installed "$am"; then
      BIND_ROLE+=("$role"); BIND_SKILL+=("$am"); BIND_SOURCE+=("ask-matt")
      continue
    fi

    if [ "$n" -eq 0 ]; then
      UNRESOLVED+=("$role|empty: no installed skill fills this role")
    else
      UNRESOLVED+=("$role|ambiguous: ${n} candidates (${cands[*]}) — a split; ask-matt silent")
    fi
  done
}

discover

# ---- version delta ---------------------------------------------------------

version_delta() {
  if [ -z "$PRIOR" ]; then
    printf 'initial (no prior stamp) -> %s' "$VERSION"
  elif [ "$PRIOR" = "$VERSION" ]; then
    printf 'unchanged (%s)' "$VERSION"
  else
    printf 'bumped: %s -> %s' "$PRIOR" "$VERSION"
  fi
}

# ---- stop-and-surface ------------------------------------------------------
# Any unresolved role halts the run. No recipe is emitted — later sessions must
# never cache a guessed bind. Findings go to stderr for the human.

if [ "${#UNRESOLVED[@]}" -gt 0 ]; then
  {
    echo "pocock-bind: STOP — ${#UNRESOLVED[@]} role(s) could not be bound at version $VERSION."
    echo "Live role-binding surfaces to a human rather than guessing; no bind was written."
    echo
    for u in "${UNRESOLVED[@]}"; do
      printf '  - %s: %s\n' "${u%%|*}" "${u#*|}"
    done
    echo
    echo "Resolved so far (not cached):"
    i=0
    while [ "$i" -lt "${#BIND_ROLE[@]}" ]; do
      printf '  - %s -> %s (%s)\n' "${BIND_ROLE[$i]}" "${BIND_SKILL[$i]}" "${BIND_SOURCE[$i]}"
      i=$((i+1))
    done
    ff="$(forked_flags)"
    if [ -n "$ff" ]; then
      echo
      echo "Forked commit/merge skills (flagged, never auto-rewritten):"
      printf '  - %s\n' $ff
    fi
  } >&2
  exit 4
fi

# ---- emit ------------------------------------------------------------------

emit_bindings_block() { # two-space-indented `bindings:` map body
  local i=0
  while [ "$i" -lt "${#BIND_ROLE[@]}" ]; do
    printf '  %s: %s\n' "${BIND_ROLE[$i]}" "${BIND_SKILL[$i]}"
    i=$((i+1))
  done
}

emit_recipe() {
  local ff i
  printf 'suite: matt-pocock-skills\n'
  printf 'version: %s\n' "$VERSION"
  printf 'prior_version: %s\n' "${PRIOR:-none}"
  printf 'version_delta: %s\n' "$(version_delta)"
  printf 'bindings:\n'
  emit_bindings_block
  printf 'binding_sources:\n'
  i=0
  while [ "$i" -lt "${#BIND_ROLE[@]}" ]; do
    printf '  %s: %s\n' "${BIND_ROLE[$i]}" "${BIND_SOURCE[$i]}"
    i=$((i+1))
  done
  ff="$(forked_flags)"
  if [ -n "$ff" ]; then
    printf 'forked_flags:\n'
    printf '  - %s\n' $ff
  else
    printf 'forked_flags: []\n'
  fi
}

case "$FORMAT" in
  recipe)         emit_recipe ;;
  bindings-block) emit_bindings_block ;;
  delta)          version_delta; printf '\n' ;;
  *) echo "pocock-bind: unknown --format '$FORMAT'" >&2; exit 2 ;;
esac
