#!/usr/bin/env bash
set -euo pipefail

# Cut a release: tag `main` with the version in .claude-plugin/plugin.json and
# create the matching GitHub Release, using the CHANGELOG section as notes.
#
# The version in plugin.json is the single source of truth. Bump it (and add a
# CHANGELOG section) on the dev->main release PR; run this once that PR has
# landed on main.
#
# Usage:
#   ./scripts/release.sh            # tag + push + GitHub Release for current plugin.json version
#   ./scripts/release.sh --dry-run  # print what would happen, change nothing
#
# Guards (all must pass, else it refuses):
#   - run from a clean working tree on `main`
#   - tag v<version> must not already exist (bump plugin.json first)
#   - CHANGELOG.md must have a "## [<version>]" section (the release notes)

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_JSON="$REPO/.claude-plugin/plugin.json"
CHANGELOG="$REPO/CHANGELOG.md"

dry_run=0
[ "${1:-}" = "--dry-run" ] && dry_run=1

die() { echo "error: $*" >&2; exit 1; }

# --- read the canonical version -------------------------------------------
read_version() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.version' "$PLUGIN_JSON"
  else
    # fallback: first "version": "x.y.z" line
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1
  fi
}

[ -f "$PLUGIN_JSON" ] || die "$PLUGIN_JSON not found"
VERSION="$(read_version)"
[ -n "$VERSION" ] || die "could not read version from $PLUGIN_JSON"
TAG="v$VERSION"

# --- extract the CHANGELOG section for this version -----------------------
# Everything between "## [<version>]" and the next "## " heading.
NOTES="$(awk -v ver="$VERSION" '
  $0 ~ "^## \\[" ver "\\]" { grab=1; next }
  grab && /^## / { exit }
  grab && /^\[[^]]+\]:[[:space:]]/ { exit }   # link-reference block at EOF
  grab { print }
' "$CHANGELOG" | sed '/^$/d')"

[ -n "$NOTES" ] || die "no '## [$VERSION]' section in CHANGELOG.md — add release notes first"

# --- guards ----------------------------------------------------------------
branch="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
[ "$branch" = "main" ] || die "must release from 'main' (on '$branch'). Land the release PR first."

[ -z "$(git -C "$REPO" status --porcelain)" ] || die "working tree not clean — commit or stash first"

if git -C "$REPO" rev-parse "$TAG" >/dev/null 2>&1; then
  die "tag $TAG already exists. Bump 'version' in plugin.json (and CHANGELOG) for a new release."
fi

# --- act -------------------------------------------------------------------
echo "release $TAG (version $VERSION)"
echo "--- notes ---"
echo "$NOTES"
echo "-------------"

if [ "$dry_run" -eq 1 ]; then
  echo "[dry-run] would: git tag -a $TAG && git push origin $TAG && gh release create $TAG"
  exit 0
fi

git -C "$REPO" tag -a "$TAG" -m "release $TAG"
git -C "$REPO" push origin "$TAG"

if command -v gh >/dev/null 2>&1; then
  printf '%s\n' "$NOTES" | gh release create "$TAG" --title "$TAG" --notes-file - --repo stonematt/stonematt-skills
  echo "created GitHub Release $TAG"
else
  echo "warning: gh not found — tag pushed, but no GitHub Release created." >&2
  echo "create it manually: gh release create $TAG --title $TAG --notes-file <(...)" >&2
fi
