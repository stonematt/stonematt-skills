#!/usr/bin/env bash
# stone-skill-rename — migrate old unnamespaced skill refs to stone-* namespace.
# Targets a repo's CLAUDE.md + its per-project Claude memory dir.
# Dry-run by default; pass --apply to write.
#
# Usage:
#   stone-skill-rename [REPO_DIR] [--apply]   migrate one repo (dry-run unless --apply)
#   stone-skill-rename --list [ROOT]          emit repo paths under ROOT for fan-out
#   (REPO_DIR / ROOT default to $PWD)
#
# Mapping (old -> new):
#   /commit /merge /promote-settings /ai-sniff-test /client-report
#   /journal /journal-status  ->  /stone-*
#   /sync-plugin-manifest  ->  REMOVED (flagged, never rewritten)

set -euo pipefail

# --- args ---------------------------------------------------------------
APPLY=0
LIST=0
REPO="$PWD"
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --list)  LIST=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) REPO="$a" ;;
  esac
done

REPO="$(cd "$REPO" && pwd)"                 # absolutise (repo, or ROOT in --list)

# --- list mode: emit candidate repo paths (one per line, stdout) --------
# A "repo" = any dir under ROOT holding a CLAUDE.md. Pure path list for
# machine/subagent consumption; the summary goes to stderr so it does not
# pollute the list. Feed each line to a per-repo dry-run.
if [ $LIST -eq 1 ]; then
  n=0
  while IFS= read -r f; do
    printf '%s\n' "${f%/CLAUDE.md}"
    n=$((n+1))
  done < <(
    find "$REPO" -name CLAUDE.md \
      -not -path '*/node_modules/*' \
      -not -path '*/.git/*' \
      -not -path '*/.next/*' \
      -not -path '*/dist/*' 2>/dev/null | sort
  )
  echo "Found $n repo(s) with CLAUDE.md under $REPO" >&2
  exit 0
fi
SLUG="$(printf '%s' "$REPO" | sed 's#[/.]#-#g')"
MEM="$HOME/.claude/projects/$SLUG/memory"

# Regex: leading-slash anchor makes it idempotent — /stone-commit has '-'
# (not '/') before the verb, so it never re-matches. journal-status is
# covered by the /journal\b alternative collapsing to the same target.
VERBS='commit|merge|promote-settings|ai-sniff-test|client-report|journal-status|journal'
RX="/(${VERBS})\b"

# --- collect target files (skip .archive/ and the mapping memory) -------
files=()
[ -f "$REPO/CLAUDE.md" ] && files+=("$REPO/CLAUDE.md")
if [ -d "$MEM" ]; then
  while IFS= read -r f; do files+=("$f"); done < <(
    find "$MEM" -name '*.md' \
      -not -path '*/.archive/*' \
      -not -name 'reference_skill_rename.md'
  )
fi

if [ ${#files[@]} -eq 0 ]; then
  echo "No CLAUDE.md or memory files found for: $REPO"
  echo "  (memory dir checked: $MEM)"
  exit 0
fi

echo "Repo:   $REPO"
echo "Memory: $MEM"
echo "Mode:   $([ $APPLY -eq 1 ] && echo APPLY || echo 'dry-run (pass --apply to write)')"
echo

# --- removed-skill warning (manual fix; no auto-rewrite) ----------------
if grep -rln '/sync-plugin-manifest' "${files[@]}" 2>/dev/null | grep -q .; then
  echo "WARNING: /sync-plugin-manifest is REMOVED with no replacement. Fix by hand:"
  grep -rn '/sync-plugin-manifest' "${files[@]}" 2>/dev/null | sed 's/^/  /'
  echo
fi

# --- show pending rewrites ---------------------------------------------
hits=0
for f in "${files[@]}"; do
  while IFS= read -r line; do
    [ $hits -eq 0 ] && echo "Pending rewrites:"
    hits=$((hits+1))
    echo "  ${f#$HOME/}:$line"
  done < <(perl -ne "print \"\$.: \$_\" if m{$RX}" "$f")
done

if [ $hits -eq 0 ]; then
  echo "Clean — no stale skill refs."
  exit 0
fi
echo

# --- apply --------------------------------------------------------------
if [ $APPLY -eq 1 ]; then
  for f in "${files[@]}"; do
    perl -i -pe "s{$RX}{/stone-\$1}g" "$f"
  done
  echo "Applied. Re-verifying..."
  rem=$(for f in "${files[@]}"; do perl -ne "print if m{$RX}" "$f"; done | wc -l | tr -d ' ')
  if [ "$rem" = "0" ]; then
    echo "Clean. ($hits ref(s) rewritten)"
  else
    echo "WARNING: $rem ref(s) still match after rewrite — inspect manually."
    exit 1
  fi
  echo
  echo "Next: commit CLAUDE.md on a feature branch (never dev/master):"
  echo "  git checkout -b docs/stone-skill-rename && git add CLAUDE.md"
else
  echo "Dry-run only. Re-run with --apply to write."
fi
