#!/usr/bin/env bash
#
# journal-sweep — walk a repo tree, find repos whose dev-journals are out of
# date, and dispatch headless `claude -p "/stone-journal ..."` runs to backfill.
#
# Designed for unattended launchd use (00:30 nightly). Also runnable by hand.
#
# Usage:
#   journal-sweep.sh [--dry-run] [--json] [--config PATH] [--root DIR]
#
#   --dry-run   detect + report only; never dispatch (no LLM, no cost)
#   --json      machine-readable classification (one JSON object per line)
#   --config    path to config file (default: alongside this script)
#   --root      override ROOT (the tree to walk)
#
# Detection signal is commits (author date) vs newest journal entry date.
# Date math uses BSD `date` (macOS). Locking is mkdir-atomic (flock absent on macOS).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
JSON=0
CONFIG="${JOURNAL_SWEEP_CONFIG:-$SCRIPT_DIR/journal-sweep.config}"
ROOT_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --json)    JSON=1 ;;
    --config)  CONFIG="$2"; shift ;;
    --root)    ROOT_OVERRIDE="$2"; shift ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# shellcheck disable=SC1090
. "$CONFIG"
[ -n "$ROOT_OVERRIDE" ] && ROOT="$ROOT_OVERRIDE"

# Defaults so a partial config can't crash the run under `set -u`.
: "${ROOT:?ROOT must be set in the config or via --root}"
ALLOWLIST="${ALLOWLIST:-}"
TIMEOUT="${TIMEOUT:-300}"
CONCURRENCY="${CONCURRENCY:-3}"
MODEL="${MODEL:-sonnet}"
PERMISSION_MODE="${PERMISSION_MODE:-bypassPermissions}"
AUTHORS="${AUTHORS:-}"
LOG="${LOG:-$HOME/Library/Logs/journal-sweep.log}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/journal-sweep}"
DISCOVER_QUEUE="${DISCOVER_QUEUE:-$STATE_DIR/discover-queue.md}"
NOTIFY="${NOTIFY:-0}"

# Today/yesterday — overridable for deterministic tests.
TODAY="${JOURNAL_SWEEP_TODAY:-$(date +%F)}"
YESTERDAY="$(date -j -v-1d -f "%Y-%m-%d" "$TODAY" "+%F")"

# ---- helpers --------------------------------------------------------------

# Walk the tree; emit absolute repo-root paths (dir containing a .git DIRECTORY).
# Stops descending at each repo root -> auto-skips submodules, nested repos,
# linked worktrees (their .git is a FILE), and .journal worktrees.
walk() {
  local dir="$1" child
  if [ -d "$dir/.git" ]; then
    printf '%s\n' "$dir"
    return 0
  fi
  for child in "$dir"/*; do
    [ -d "$child" ] || continue
    [ -L "$child" ] && continue
    walk "$child"
  done
}

# Extract lowercased owner from origin remote (git@host:owner/..  or  scheme://host/owner/..).
origin_owner() {
  local url owner="" rest
  url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 0
  [ -z "$url" ] && return 0
  case "$url" in
    git@*:*)  owner="${url#*:}";       owner="${owner%%/*}" ;;
    *://*)    rest="${url#*://}"; rest="${rest#*/}"; owner="${rest%%/*}" ;;
  esac
  printf '%s' "$owner" | tr '[:upper:]' '[:lower:]'
}

in_allowlist() { case " $ALLOWLIST " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# Newest journal entry date from .journal/docs/journal/YYYY-MM-DD.md filenames.
last_entry_date() {
  ls "$1/.journal/docs/journal/"*.md 2>/dev/null \
    | sed -E 's#.*/([0-9]{4}-[0-9]{2}-[0-9]{2})\.md$#\1#' \
    | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort | tail -1
}

# Newest commit author date (optionally filtered to AUTHORS regex).
last_commit_date() {
  if [ -n "${AUTHORS:-}" ]; then
    git -C "$1" log --all --author="$AUTHORS" -1 --format=%ad --date=short 2>/dev/null
  else
    git -C "$1" log --all -1 --format=%ad --date=short 2>/dev/null
  fi
}

# Classify one repo root -> prints "relpath<TAB>json"
classify() {
  local root="$1" rel le lc start
  rel="${root#"$ROOT"/}"; [ "$rel" = "$root" ] && rel="$(basename "$root")"

  if [ -d "$root/.journal" ]; then
    le="$(last_entry_date "$root")"
    if [ -z "$le" ]; then
      printf '%s\t{"repo":"%s","action":"empty"}\n' "$rel" "$rel"
      return
    fi
    lc="$(last_commit_date "$root")"
    start="$(date -j -v+1d -f "%Y-%m-%d" "$le" "+%F" 2>/dev/null)"
    # stale iff there is a commit newer than the last entry AND the backfill
    # range [start..yesterday] is non-empty (start <= yesterday => today excluded).
    if [ -n "$lc" ] && [ "$lc" \> "$le" ] && [ ! "$start" \> "$YESTERDAY" ]; then
      printf '%s\t{"repo":"%s","action":"stale","start":"%s","end":"%s"}\n' \
        "$rel" "$rel" "$start" "$YESTERDAY"
    else
      printf '%s\t{"repo":"%s","action":"current"}\n' "$rel" "$rel"
    fi
  else
    local owner; owner="$(origin_owner "$root")"
    if in_allowlist "$owner"; then
      printf '%s\t{"repo":"%s","action":"discover","owner":"%s"}\n' "$rel" "$rel" "$owner"
    else
      printf '%s\t{"repo":"%s","action":"ignore","owner":"%s"}\n' "$rel" "$rel" "$owner"
    fi
  fi
}

# Detect across the tree -> sorted classification lines (relpath stripped).
detect() {
  local root
  walk "$ROOT" | while IFS= read -r root; do
    classify "$root"
  done | sort -t"$(printf '\t')" -k1,1 | cut -f2-
}

# ---- human-readable rendering --------------------------------------------

render_human() {
  local line
  while IFS= read -r line; do
    case "$line" in
      *'"action":"stale"'*)
        printf 'STALE    %-45s %s..%s\n' \
          "$(json_get "$line" repo)" "$(json_get "$line" start)" "$(json_get "$line" end)" ;;
      *'"action":"current"'*)  printf 'current  %s\n' "$(json_get "$line" repo)" ;;
      *'"action":"empty"'*)    printf 'EMPTY    %-45s (worktree but no entries — onboard by hand)\n' "$(json_get "$line" repo)" ;;
      *'"action":"discover"'*) printf 'DISCOVER %-45s (owned, no .journal: %s)\n' "$(json_get "$line" repo)" "$(json_get "$line" owner)" ;;
      *'"action":"ignore"'*)   printf 'ignore   %s\n' "$(json_get "$line" repo)" ;;
    esac
  done
}

# Tiny field extractor for our own flat JSON (no jq dependency).
json_get() { printf '%s' "$1" | sed -E "s/.*\"$2\":\"([^\"]*)\".*/\1/"; }

# ---- dispatch -------------------------------------------------------------

# Run each "repo|start|end" job through a headless /stone-journal, capped at
# CONCURRENCY workers. Skip-and-continue: a failing/timing-out repo never
# aborts the batch. Emits one "RESULT <ok|failed|timeout> <repo> <s>..<e>" line
# per job on stdout.
dispatch_jobs() {
  export ROOT TIMEOUT MODEL PERMISSION_MODE
  printf '%s\n' "$@" | xargs -P "$CONCURRENCY" -I{} bash -c '
    job="$1"; repo="${job%%|*}"; r="${job#*|}"; start="${r%%|*}"; end="${r##*|}"
    if cd "$ROOT/$repo" 2>/dev/null; then
      timeout "$TIMEOUT" claude -p "/stone-journal for $start through $end" \
        --model "$MODEL" --permission-mode "$PERMISSION_MODE" >/dev/null 2>&1
      rc=$?
    else
      rc=200
    fi
    case "$rc" in 0) st=ok ;; 124) st=timeout ;; *) st=failed ;; esac
    printf "RESULT %s %s %s..%s\n" "$st" "$repo" "$start" "$end"
  ' _ {}
}

# ---- outputs --------------------------------------------------------------

timestamp() { date '+%Y-%m-%dT%H:%M:%S'; }
# Emit a structured progress line. launchd routes stdout -> $LOG; manual runs
# see it on the terminal.
emit() { printf '%s %s\n' "$(timestamp)" "$*"; }

# Queue an owned-but-unjournaled repo for onboarding. Setup is heavy +
# interactive, so we never auto-onboard. We append a markdown task to a plain
# file (NO obsidian CLI — launchd may run with Obsidian closed); the user's
# Obsidian daily processor ingests this file.
discover_to_queue() {
  local repo="$1" owner="$2"
  mkdir -p "$(dirname "$DISCOVER_QUEUE")" 2>/dev/null
  printf -- '- [ ] Onboard `%s` (owner: %s) — no `.journal` yet [seen %s]\n' \
    "$repo" "$owner" "$(date '+%Y-%m-%d')" >> "$DISCOVER_QUEUE"
}

# Single-instance lock (flock is absent on macOS; mkdir is atomic). Reclaims a
# stale lock whose holder PID is dead so a crashed run can't wedge the schedule.
acquire_lock() {
  local d="$STATE_DIR/lock.d" pid
  if mkdir "$d" 2>/dev/null; then printf '%s\n' "$$" > "$d/pid"; return 0; fi
  pid="$(cat "$d/pid" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then return 1; fi
  rm -rf "$d"
  if mkdir "$d" 2>/dev/null; then printf '%s\n' "$$" > "$d/pid"; return 0; fi
  return 1
}
release_lock() { rm -rf "$STATE_DIR/lock.d" 2>/dev/null; }

# Desktop notification — only called on attention (failures / new discover).
notify() {
  [ "${NOTIFY:-0}" -eq 1 ] || return 0
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"$1\" with title \"journal-sweep\"" >/dev/null 2>&1 || true
}

# ---- main -----------------------------------------------------------------

main() {
  local results line action repo owner s e rline failures=0
  results="$(detect)"

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$JSON" -eq 1 ]; then
      printf '%s\n' "$results"
    else
      printf '%s\n' "$results" | render_human
    fi
    return 0
  fi

  mkdir -p "$STATE_DIR" 2>/dev/null
  if ! acquire_lock; then
    emit "another journal-sweep holds the lock — exiting"
    return 0
  fi
  trap 'release_lock' EXIT

  local seen="$STATE_DIR/seen-repos"; touch "$seen"
  emit "=== journal-sweep run (today=$TODAY, yesterday=$YESTERDAY) ==="

  local -a jobs=() discover_new=()
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    action="$(json_get "$line" action)"; repo="$(json_get "$line" repo)"
    case "$action" in
      stale)
        s="$(json_get "$line" start)"; e="$(json_get "$line" end)"
        jobs+=("$repo|$s|$e")
        ;;
      empty)
        emit "EMPTY $repo (worktree but no entries — onboard by hand)"
        ;;
      discover)
        owner="$(json_get "$line" owner)"
        if grep -qxF "$repo" "$seen"; then
          : # already surfaced — dedup, stay silent
        else
          discover_to_queue "$repo" "$owner"
          printf '%s\n' "$repo" >> "$seen"
          discover_new+=("$repo")
          emit "DISCOVER(new) $repo (owned: $owner) -> $DISCOVER_QUEUE"
        fi
        ;;
    esac
  done <<EOF
$results
EOF

  if [ "${#jobs[@]}" -gt 0 ]; then
    emit "dispatching ${#jobs[@]} stale repo(s), concurrency=$CONCURRENCY"
    while IFS= read -r rline; do
      emit "$rline"
      case "$rline" in RESULT\ failed\ *|RESULT\ timeout\ *) failures=$((failures+1)) ;; esac
    done < <(dispatch_jobs "${jobs[@]}")
  else
    emit "no stale repos"
  fi

  if [ "$failures" -gt 0 ] || [ "${#discover_new[@]}" -gt 0 ]; then
    notify "${failures} failure(s), ${#discover_new[@]} new repo(s) to onboard"
    emit "NOTIFY attention (failures=$failures new_discover=${#discover_new[@]})"
  else
    emit "clean run — no notification"
  fi
  emit "=== done ==="
}

main
