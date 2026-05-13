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
# Resolves the project slug from the current working directory (absolute
# path with "/" → "-"). Run from the repo root or main worktree, not the
# .journal worktree.

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
SLUG=$(printf '%s' "$PROJECT_DIR" | sed 's|/|-|g')
CLAUDE_PROJ_DIR="$HOME/.claude/projects/$SLUG"
MEMORY_DIR="$CLAUDE_PROJ_DIR/memory"
PLANS_DIR="$HOME/.claude/plans"

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
echo "# Slug: $SLUG"
echo

# -------- Memory files --------
echo "## Memory (curated learnings)"
if [ -d "$MEMORY_DIR" ]; then
  # shellcheck disable=SC2207
  FILES=($(find "$MEMORY_DIR" -maxdepth 2 -name '*.md' \
    -newermt "$START" ! -newermt "$END_NEXT" 2>/dev/null | sort))
  if [ "${#FILES[@]}" -eq 0 ]; then
    echo "_(no memory files created or modified in range)_"
  else
    for f in "${FILES[@]}"; do
      echo
      echo "### $(basename "$f")"
      echo '```'
      cat "$f" | redact
      echo '```'
    done
  fi
else
  echo "_(no memory dir — $MEMORY_DIR does not exist)_"
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
if [ -d "$CLAUDE_PROJ_DIR" ]; then
  # shellcheck disable=SC2207
  SESSIONS=($(find "$CLAUDE_PROJ_DIR" -maxdepth 1 -name '*.jsonl' \
    -newermt "$START" ! -newermt "$END_NEXT" 2>/dev/null | sort))
  if [ "${#SESSIONS[@]}" -eq 0 ]; then
    echo "_(no transcripts in range)_"
  else
    for t in "${SESSIONS[@]}"; do
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
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        out = []
        for block in c:
            if isinstance(block, dict):
                if "text" in block:
                    out.append(block["text"])
                elif block.get("type") == "tool_result":
                    r = block.get("content")
                    if isinstance(r, str):
                        out.append(r)
                    elif isinstance(r, list):
                        for sub in r:
                            if isinstance(sub, dict) and "text" in sub:
                                out.append(sub["text"])
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
  fi
else
  echo "_(no project transcript dir — $CLAUDE_PROJ_DIR does not exist)_"
fi

echo
echo "# END enrichment"
