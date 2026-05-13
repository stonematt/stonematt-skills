#!/usr/bin/env bash
# Commits journal entries inside the .journal worktree.
# Usage: journal-commit.sh <worktree-path> <commit-message>
#
# Follows the same conventions as the /commit skill:
# - Conventional Commits format
# - Heredoc for commit message
# - Co-Authored-By trailer
#
# Uses git -C to avoid cd chains and permission prompt issues.

set -euo pipefail

WORKTREE="${1:?Usage: journal-commit.sh <worktree-path> <commit-message>}"
MESSAGE="${2:?Usage: journal-commit.sh <worktree-path> <commit-message>}"

git -C "$WORKTREE" add docs/journal/
git -C "$WORKTREE" commit -m "$MESSAGE"
