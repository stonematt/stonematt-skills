#!/usr/bin/env bash
# Derive auto-memory directory from current working directory.
# Pattern matches Claude Code's project slug convention:
#   /Users/foo/src/proj  ->  ~/.claude/projects/-Users-foo-src-proj/memory/
#
# Usage: memory-dir.sh [project-root]
#   project-root defaults to $CLAUDE_PROJECT_DIR or pwd
set -euo pipefail

root="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
# Resolve to absolute path
root="$(cd "$root" && pwd)"
# Claude Code's project slug: replace both '/' and '.' with '-'
slug="${root//\//-}"
slug="${slug//./-}"
dir="$HOME/.claude/projects/${slug}/memory"

echo "$dir"
