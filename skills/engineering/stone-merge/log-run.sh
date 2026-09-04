#!/usr/bin/env bash
# log-run.sh — append one JSONL row recording a /stone-merge run.
#
# Central across repos: the skill directory is symlinked into
# ~/.claude/skills/stone-merge, so every repo calls the same script and every
# run lands in one log regardless of where it was invoked from.
#
# Log:  ${XDG_STATE_HOME:-$HOME/.local/state}/stone-merge/runs.jsonl
# Override with STONE_MERGE_LOG for a one-off or a test.
#
# Deliberately NOT ~/.claude — writes there come back blocked by the auto-mode
# classifier (observed 2026-09-04 on both `cp` and the Write tool). XDG state is
# the right home anyway: durable, unlike ~/.cache, which gets swept.
#
# Fail-open, always. A logging failure must never cost a merge that already
# happened. Every path exits 0.
#
# No file lock on the append. open(path, "a") is O_APPEND, and the row is one
# small write flushed at close — two merges landing in the same instant across
# repos isn't a real workload for this tool. Revisit only if a torn line ever
# shows up in the log.
#
# Usage:
#   log-run.sh --pr 99 --base dev --outcome merged [--field value ...]
#
# Recognized fields (all optional except --pr and --outcome):
#   --pr N              PR number
#   --base BRANCH       base branch merged into
#   --outcome S         merged | stopped | blocked
#   --sha SHA           merge commit
#   --repo SLUG         owner/repo (auto-detected when omitted)
#   --gate S            how the review gate resolved: docs-only | ci-check |
#                       reviewer:<name> | policy-optional | asked | waived
#   --checks S          pass | fail | none | rerun-passed
#   --conflicts S       none, or a short description of what was resolved
#   --labels S          issues labeled, or "none"
#   --classifier S      verbatim denial text, or "none"
#   --duration N        seconds
#   --note S            anything the run should carry forward
#
# Unrecognized --flags are stored as-is, so the schema can grow without
# editing this script.

set -u

log_path="${STONE_MERGE_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/stone-merge/runs.jsonl}"

mkdir -p "$(dirname "$log_path")" 2>/dev/null || exit 0

# Repo slug from origin, owner/repo only — strip protocol, host, credentials so
# nothing sensitive lands on disk. Handles SSH and HTTPS remote forms.
detect_repo() {
  local url
  url="$(git remote get-url origin 2>/dev/null || echo "")"
  [ -z "$url" ] && return
  printf '%s' "$url" \
    | sed -E 's#\.git/?$##' \
    | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#'
}

# Build the row with python3 so field values are JSON-escaped properly. Denial
# text and conflict descriptions carry quotes and newlines; hand-built JSON
# corrupts the log the one time it matters most.
command -v python3 >/dev/null 2>&1 || exit 0

STONE_MERGE_LOG_PATH="$log_path" \
STONE_MERGE_REPO_FALLBACK="$(detect_repo)" \
python3 - "$@" <<'PY' || exit 0
import json, os, sys, datetime

def main():
    args = sys.argv[1:]
    row = {}
    i = 0
    while i < len(args):
        a = args[i]
        if a.startswith("--"):
            key = a[2:].replace("-", "_")
            # Every recognized flag takes a value (see usage above) — including
            # ones whose value itself starts with "--" (e.g. verbatim classifier
            # denial text quoting a flag like --dangerously-skip-permissions).
            # Only treat a flag as valueless when it's the very last argument.
            if i + 1 < len(args):
                val = args[i + 1]
                i += 2
            else:
                val = True
                i += 1
            row[key] = val
        else:
            i += 1

    if not row.get("repo"):
        fallback = os.environ.get("STONE_MERGE_REPO_FALLBACK", "").strip()
        if fallback:
            row["repo"] = fallback

    row["ts"] = datetime.datetime.now().astimezone().isoformat(timespec="seconds")

    # Fail-open protects the write, not a caller that forgot a field — warn so
    # a partial row is never discovered only at analysis time.
    for field in ("pr", "outcome"):
        if field not in row:
            print(f"stone-merge log: missing --{field}", file=sys.stderr)

    # Stable key order so the file stays readable by eye, unknown keys appended.
    order = ["ts", "repo", "pr", "base", "outcome", "sha", "gate", "checks",
             "conflicts", "labels", "classifier", "duration", "note"]
    ordered = {k: row[k] for k in order if k in row}
    ordered.update({k: v for k, v in row.items() if k not in ordered})

    path = os.environ["STONE_MERGE_LOG_PATH"]
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(ordered, ensure_ascii=False) + "\n")

# Fail-open extends to this block too — an unexpected exception here must
# never surface as a noisy traceback on the happy path, only our own warnings.
try:
    main()
except Exception:
    pass
PY

exit 0
