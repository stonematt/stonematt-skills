#!/usr/bin/env bash
set -euo pipefail

# Build a claude.ai-uploadable zip bundle for one skill, optionally
# bundling one or more persona files alongside it.
#
# Usage:
#   ./scripts/build-claudeai-zip.sh <skill> [persona-slug ...]
#
# Examples:
#   ./scripts/build-claudeai-zip.sh commit
#   ./scripts/build-claudeai-zip.sh voice lithos
#   ./scripts/build-claudeai-zip.sh email lithos nwhub
#
# Output: stonematt-<skill>[-<persona>...].zip in the repo root.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO/.claudeai-build"
CONFIG_DIR="${STONEMATT_SKILLS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/stonematt-skills}"

if [ $# -lt 1 ]; then
  echo "usage: $0 <skill> [persona-slug ...]" >&2
  exit 1
fi

skill="$1"
shift
personas=("$@")

# Resolve the skill source dir.
skill_src=""
while IFS= read -r -d '' candidate; do
  if [ "$(basename "$(dirname "$candidate")")" = "$skill" ]; then
    skill_src="$(dirname "$candidate")"
    break
  fi
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -print0)

if [ -z "$skill_src" ]; then
  echo "error: skill '$skill' not found under $REPO/skills/" >&2
  exit 1
fi

# Stage the bundle.
stage="$BUILD_DIR/$skill"
rm -rf "$stage"
mkdir -p "$stage"
cp -R "$skill_src/." "$stage/"

# Bundle personas, if any.
if [ ${#personas[@]} -gt 0 ]; then
  mkdir -p "$stage/persona"
  for slug in "${personas[@]}"; do
    src="$CONFIG_DIR/persona/$slug"
    if [ ! -d "$src" ]; then
      echo "error: persona '$slug' not found at $src" >&2
      echo "  hint: run ./bin/persona-init $slug to scaffold it" >&2
      exit 1
    fi
    cp -R "$src" "$stage/persona/$slug"
    echo "bundled persona: $slug ($src)"
  done
fi

# Build the zip.
name="stonematt-$skill"
if [ ${#personas[@]} -gt 0 ]; then
  for slug in "${personas[@]}"; do
    name="$name-$slug"
  done
fi
out="$REPO/$name.zip"
rm -f "$out"
(cd "$stage" && zip -qr "$out" .)

echo "built $out"
echo "upload via Claude.ai Settings → Features → Skills"
