#!/usr/bin/env bash
set -uo pipefail

# Tell a consumer whether their installed stonematt-skills is current.
#
# Compares the local pack version against the latest release on GitHub.
# Needs only curl (no gh, no jq) so it runs anywhere a consumer installed.
#
# Usage:
#   ./scripts/check-latest.sh                 # auto-detect local version
#   ./scripts/check-latest.sh /path/to/plugin.json
#
# Exit codes: 0 = current or ahead, 1 = behind (update available), 2 = could
# not determine (no local anchor or network failure).
#
# NOTE: the `npx skills add` path copies individual skill dirs and does NOT
# carry .claude-plugin/plugin.json, so there is no local anchor for that
# install. It works for plugin-marketplace installs and repo clones. Per-skill
# version stamping (frontmatter at build time) is the follow-up that closes
# that gap.

REPO_SLUG="stonematt/stonematt-skills"
RAW_PLUGIN="https://raw.githubusercontent.com/$REPO_SLUG/main/.claude-plugin/plugin.json"
RELEASES_API="https://api.github.com/repos/$REPO_SLUG/releases/latest"

# Portable across BSD (macOS) and GNU sed — no `\|` alternation (GNU-only).
# Matches "version": "x.y.z" or "tag_name": "vx.y.z", stripping any leading v.
extract_version() {
  sed -n \
    -e 's/.*"version"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' \
    -e 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' \
    | head -1
}

# --- locate the local version anchor --------------------------------------
local_json=""
if [ "$#" -ge 1 ]; then
  local_json="$1"
else
  # walk up from cwd looking for .claude-plugin/plugin.json
  dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.claude-plugin/plugin.json" ]; then local_json="$dir/.claude-plugin/plugin.json"; break; fi
    dir="$(dirname "$dir")"
  done
  # common plugin-marketplace install location
  if [ -z "$local_json" ]; then
    cand="$(find "$HOME/.claude/plugins" -path '*stonematt-skills*/.claude-plugin/plugin.json' 2>/dev/null | head -1)"
    [ -n "$cand" ] && local_json="$cand"
  fi
fi

if [ -z "$local_json" ] || [ ! -f "$local_json" ]; then
  echo "could not find a local plugin.json to read your version." >&2
  echo "pass the path explicitly: $0 /path/to/.claude-plugin/plugin.json" >&2
  exit 2
fi

local_ver="$(extract_version < "$local_json")"
[ -n "$local_ver" ] || { echo "could not read version from $local_json" >&2; exit 2; }

# --- fetch the latest published version -----------------------------------
remote_ver="$(curl -fsSL "$RELEASES_API" 2>/dev/null | extract_version)"
if [ -z "$remote_ver" ]; then
  # no releases yet (or API blocked) — fall back to the version on main
  remote_ver="$(curl -fsSL "$RAW_PLUGIN" 2>/dev/null | extract_version)"
fi
[ -n "$remote_ver" ] || { echo "could not reach GitHub to determine the latest version." >&2; exit 2; }

# --- compare (semver-ish via sort -V) -------------------------------------
echo "local:  $local_ver"
echo "latest: $remote_ver"

if [ "$local_ver" = "$remote_ver" ]; then
  echo "up to date."
  exit 0
fi

newest="$(printf '%s\n%s\n' "$local_ver" "$remote_ver" | sort -V | tail -1)"
if [ "$newest" = "$local_ver" ]; then
  echo "ahead of the latest release (dev/local build)."
  exit 0
fi

echo "behind — update available. Re-run your install:"
echo "  npx skills@latest add $REPO_SLUG          # filesystem agents"
echo "  /plugin marketplace add $REPO_SLUG        # Claude Code plugin"
exit 1
