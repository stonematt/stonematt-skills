#!/usr/bin/env bash
# Snapshot git + PR state for /checkpoint. Prints a structured report
# the skill can paste into the checkpoint markdown body.
#
# Usage: gather-state.sh
# Run from inside the project repo.
set -euo pipefail

echo "## Git"
branch="$(git branch --show-current 2>/dev/null || echo '(detached)')"
echo "branch: $branch"

last="$(git log -1 --format='%h %s' 2>/dev/null || echo '(no commits)')"
echo "last_commit: $last"

# Upstream sync state (ahead/behind)
if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  ahead_behind="$(git rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo '? ?')"
  behind="${ahead_behind%$'\t'*}"
  ahead="${ahead_behind#*$'\t'}"
  echo "upstream: $upstream (ahead $ahead, behind $behind)"
else
  echo "upstream: (none)"
fi

echo
echo "## Working tree"
status="$(git status --short 2>/dev/null || true)"
if [ -z "$status" ]; then
  echo "(clean)"
else
  echo "$status"
fi

echo
echo "## Open PRs from this branch"
if command -v gh >/dev/null 2>&1; then
  if [ -n "$branch" ] && [ "$branch" != "(detached)" ]; then
    gh pr list --head "$branch" --json number,title,state,url \
      --jq '.[] | "#\(.number) [\(.state)] \(.title)\n  \(.url)"' 2>/dev/null \
      || echo "(gh pr list failed — auth?)"
  else
    echo "(detached HEAD — skipping)"
  fi
else
  echo "(gh not installed)"
fi
