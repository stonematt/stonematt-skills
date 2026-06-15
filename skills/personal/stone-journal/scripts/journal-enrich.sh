#!/usr/bin/env bash
# Gather non-git signal for a date range to enrich journal synthesis.
#
# Prints a consolidated, redacted digest to stdout covering:
#   - Claude Code transcript excerpts (user + assistant, filtered to vendor
#     / decision / out-of-band patterns)
#   - Memory files created or modified in the range (these are curated
#     learnings)
#   - Plan files created or modified in the range (intents vs shipped)
#
# Usage:  journal-enrich.sh <start-date YYYY-MM-DD> [<end-date YYYY-MM-DD>]
# If end-date omitted, uses start-date (single-day mode).
#
# Project-dir resolution (works in any repo):
#   Claude Code stores per-project transcripts/memory under
#   ~/.claude/projects/<slug>, where <slug> is the cwd with separators mapped
#   to '-'. The exact mapping has changed across Claude Code versions — '.'
#   used to be preserved (…-github.com-…) and is now replaced (…-github-com-…),
#   so a single repo's history can be split across BOTH slug dirs. Rather than
#   reconstruct one slug (brittle), we normalize the cwd AND every candidate
#   dir name to a canonical form (all non-alphanumerics -> '-') and keep the
#   dirs whose canonical form matches exactly, unioning signal across them.
#   This tolerates whatever separator convention any Claude version used.
#   Run from the repo root / main worktree, not the .journal worktree.

set -u

START="${1:?usage: journal-enrich.sh <start-date> [end-date]}"
END="${2:-$START}"

# macOS (BSD) date vs GNU date — compute exclusive upper bound for find.
# Note: BSD date applies -v BEFORE parsing -f, so -v+1d must come before -f.
if date -v+1d "+%Y-%m-%d" >/dev/null 2>&1; then
  END_NEXT=$(date -j -v+1d -f "%Y-%m-%d" "$END" "+%Y-%m-%d")
else
  END_NEXT=$(date -d "$END +1 day" "+%Y-%m-%d")
fi

PROJECT_DIR=$(pwd)
PROJECTS_ROOT="$HOME/.claude/projects"
PLANS_DIR="$HOME/.claude/plans"

# Canonicalize a path/slug: every run of non-alphanumerics collapses to '-'.
# Comparing two strings under this normalization makes the match independent
# of which separator a given Claude version chose ('.' vs '-', etc.).
norm() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
TARGET_NORM=$(norm "$PROJECT_DIR")

# Collect every project dir whose canonical name matches the cwd's. Usually
# one; can be two when history straddles an encoding change.
PROJ_DIRS=()
if [ -d "$PROJECTS_ROOT" ]; then
  for d in "$PROJECTS_ROOT"/*/; do
    [ -d "$d" ] || continue
    if [ "$(norm "$(basename "$d")")" = "$TARGET_NORM" ]; then
      PROJ_DIRS+=("${d%/}")
    fi
  done
fi

# Redaction filter. Strips common secret shapes before any model sees this.
redact() {
  sed -E \
    -e 's/re_[A-Za-z0-9_-]{20,}/[REDACTED_RESEND_KEY]/g' \
    -e 's/sk-[A-Za-z0-9_-]{20,}/[REDACTED_SK]/g' \
    -e 's/ghp_[A-Za-z0-9]{20,}/[REDACTED_GHP]/g' \
    -e 's/ghs_[A-Za-z0-9]{20,}/[REDACTED_GHS]/g' \
    -e 's/AIza[A-Za-z0-9_-]{20,}/[REDACTED_GOOGLE]/g' \
    -e 's/xox[bp]-[A-Za-z0-9-]{20,}/[REDACTED_SLACK]/g' \
    -e 's/Bearer [A-Za-z0-9._~+/-]+=*/Bearer [REDACTED]/g' \
    -e 's/[A-Fa-f0-9]{40,}/[REDACTED_HEX]/g'
}

# Keywords that usually indicate durable, journal-worthy content.
# Extend as patterns emerge. Match in any case.
PATTERN='signed up|sign up|signup|account|verified|verify domain|verification|added (dns|record|mx|spf|dkim|dmarc|cname|txt)|dns|hover|cloudflare|resend|twilio|stripe|auth0|supabase|vercel|render|fly\.io|netlify|workspace|gateway|created account|api key|secret|wrangler|custom domain|propagation|propagated|drop(ped)?|switch(ed)? from|switch(ed)? to|going with|decided|abandoned|tried.{0,40}(failed|didn.t|queued|error)|let.?s use|instead of|replace (with)?'

echo "# Journal enrichment — $START to $END"
echo "# Project: $PROJECT_DIR"
echo "# Canonical slug: $TARGET_NORM"
if [ "${#PROJ_DIRS[@]}" -eq 0 ]; then
  echo "# Matched project dirs: (none under $PROJECTS_ROOT)"
else
  echo "# Matched project dirs (${#PROJ_DIRS[@]}):"
  for d in "${PROJ_DIRS[@]}"; do echo "#   - $(basename "$d")"; done
fi
echo

# -------- Memory files --------
echo "## Memory (curated learnings)"
mem_found=0
if [ "${#PROJ_DIRS[@]}" -gt 0 ]; then
  for d in "${PROJ_DIRS[@]}"; do
    MEMORY_DIR="$d/memory"
    [ -d "$MEMORY_DIR" ] || continue
    # shellcheck disable=SC2207
    FILES=($(find "$MEMORY_DIR" -maxdepth 2 -name '*.md' \
      -newermt "$START" ! -newermt "$END_NEXT" 2>/dev/null | sort))
    for f in "${FILES[@]:-}"; do
      [ -n "$f" ] || continue
      mem_found=1
      echo
      echo "### $(basename "$f")"
      echo '```'
      cat "$f" | redact
      echo '```'
    done
  done
fi
if [ "$mem_found" -eq 0 ]; then
  echo "_(no memory files created or modified in range)_"
fi
echo

# -------- Plan files --------
echo "## Plans (intents, pivots, cut scope)"
if [ -d "$PLANS_DIR" ]; then
  # shellcheck disable=SC2207
  PLAN_FILES=($(find "$PLANS_DIR" -maxdepth 1 -name '*.md' \
    -newermt "$START" ! -newermt "$END_NEXT" 2>/dev/null | sort))
  if [ "${#PLAN_FILES[@]}" -eq 0 ]; then
    echo "_(no plan files modified in range)_"
  else
    for f in "${PLAN_FILES[@]}"; do
      echo
      echo "### $(basename "$f")"
      # Just head — full plans are usually noisy. Synthesis can pull more if needed.
      head -60 "$f" | redact
    done
  fi
else
  echo "_(no plans dir — $PLANS_DIR does not exist)_"
fi
echo

# -------- Transcript excerpts --------
echo "## Transcripts (filtered to decisions / vendor events / out-of-band)"
tx_found=0
if [ "${#PROJ_DIRS[@]}" -gt 0 ]; then
  for d in "${PROJ_DIRS[@]}"; do
    # shellcheck disable=SC2207
    SESSIONS=($(find "$d" -maxdepth 1 -name '*.jsonl' \
      -newermt "$START" ! -newermt "$END_NEXT" 2>/dev/null | sort))
    for t in "${SESSIONS[@]:-}"; do
      [ -n "$t" ] || continue
      tx_found=1
      echo
      echo "### $(basename "$t")"
      # Extract user + assistant text content, filter to date range, grep for pattern.
      # Fields vary across versions — handle both `message.content` (string) and array.
      # Use python for robust JSONL parsing + timestamp filtering.
      python3 - "$t" "$START" "$END_NEXT" "$PATTERN" <<'PY' | redact
import json, sys, re
from datetime import datetime

path, start, end_next, pattern = sys.argv[1:5]
pat = re.compile(pattern, re.IGNORECASE)
try:
    start_dt = datetime.fromisoformat(start)
    end_dt   = datetime.fromisoformat(end_next)
except Exception as e:
    print(f"_(range parse error: {e}; start={start!r} end_next={end_next!r})_", file=sys.stderr)
    sys.exit(1)

def text_of(msg):
    # Only authored prose (typed user messages, assistant text). Tool-result
    # blocks are deliberately skipped — they're file reads / command output /
    # injected skill docs, which flood the keyword filter with false positives
    # (line-numbered code, doc text) while rarely holding a durable decision.
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        out = []
        for block in c:
            if isinstance(block, dict) and "text" in block:
                out.append(block["text"])
        return "\n".join(out)
    return ""

with open(path, errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        ts = e.get("timestamp") or e.get("createdAt") or ""
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        except Exception:
            continue
        dt_naive = dt.replace(tzinfo=None)
        if not (start_dt <= dt_naive < end_dt):
            continue
        msg = e.get("message") or e
        role = msg.get("role") or e.get("type") or ""
        if role not in ("user", "assistant"): continue
        text = text_of(msg)
        if not text: continue
        # Split into sentences-ish and keep only lines matching the pattern.
        for chunk in re.split(r'(?<=[.!?\n])\s+', text):
            chunk = chunk.strip()
            if 10 <= len(chunk) <= 500 and pat.search(chunk):
                tag = "U" if role == "user" else "A"
                print(f"[{tag}] {chunk}")
PY
    done
  done
fi
if [ "$tx_found" -eq 0 ]; then
  echo "_(no transcripts in range)_"
fi

echo
echo "# END enrichment"
