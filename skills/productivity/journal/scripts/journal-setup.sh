#!/usr/bin/env bash
# Sets up the journal worktree and orphan branch.
# Usage: journal-setup.sh [repo-root]
#
# Idempotent — safe to run multiple times.
# Creates an orphan 'journal' branch and attaches a .journal worktree.

set -euo pipefail

REPO_ROOT="${1:-.}"

# Check if worktree already exists
if [ -d "$REPO_ROOT/.journal" ]; then
    echo "Worktree .journal already exists, nothing to do."
    exit 0
fi

# Check if journal branch already exists (local or remote)
if git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/journal 2>/dev/null; then
    echo "Branch 'journal' exists, attaching worktree..."
    git -C "$REPO_ROOT" worktree add .journal journal
else
    echo "Creating orphan 'journal' branch..."
    CURRENT_BRANCH=$(git -C "$REPO_ROOT" branch --show-current)

    git -C "$REPO_ROOT" switch --orphan journal
    git -C "$REPO_ROOT" commit --allow-empty -m "init: journal branch"
    git -C "$REPO_ROOT" switch "$CURRENT_BRANCH"
    git -C "$REPO_ROOT" worktree add .journal journal
fi

# Ensure .journal is gitignored
if ! grep -qxF '.journal' "$REPO_ROOT/.gitignore" 2>/dev/null; then
    echo '.journal' >> "$REPO_ROOT/.gitignore"
    echo "Added .journal to .gitignore"
fi

echo "Journal worktree ready at $REPO_ROOT/.journal"
