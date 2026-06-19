#!/usr/bin/env bash
set -euo pipefail

# Build a claude.ai-uploadable zip for one skill. claude.ai (Desktop/web/mobile)
# has no CLI or filesystem install path — skills are uploaded by hand via
# Settings → Customize → Skills. This produces the zip to upload.
#
# Usage:
#   ./scripts/build-claudeai-zip.sh <skill>
#
# Example:
#   ./scripts/build-claudeai-zip.sh stone-commit   # → stone-commit.zip
#
# Output: <skill>.zip in the repo root, with the skill folder at the zip root
# (myskill.zip → myskill/SKILL.md + files), the layout the uploader expects.
#
# TODO (Desktop compatibility — verify against current claude.ai uploader):
#   - The uploader caps `description` at ~200 chars; several skills exceed this
#     (kept long for Claude Code intent-triggering). Trim a copy here if rejected.
#   - Confirm metadata filename casing (`SKILL.md` vs `skill.md`); rename in the
#     staged copy if the uploader requires lowercase.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO/.claudeai-build"

if [ $# -ne 1 ]; then
  echo "usage: $0 <skill>" >&2
  exit 1
fi
skill="$1"

# Resolve the skill source dir by leaf folder name.
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

# Stage the skill in a folder named after it, so it sits at the zip root.
stage="$BUILD_DIR/$skill"
rm -rf "$stage"
mkdir -p "$stage"
cp -R "$skill_src/." "$stage/"

# Stamp the pack version so claude.ai consumers (no filesystem, no git) can see
# which release a manually-uploaded zip came from. Source of truth: plugin.json.
plugin_json="$REPO/.claude-plugin/plugin.json"
if [ -f "$plugin_json" ]; then
  version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_json" | head -1)"
  if [ -n "$version" ]; then
    printf 'stonematt-skills %s\n' "$version" > "$stage/VERSION"
  fi
fi

out="$REPO/$skill.zip"
rm -f "$out"
(cd "$BUILD_DIR" && zip -qr "$out" "$skill")

echo "built $out"
echo "upload to the claude.ai chat app (web/desktop/mobile) via Settings → Customize → Skills"
echo "note: this is NOT for the Claude Code desktop app — that uses the filesystem install (npx skills add)"
