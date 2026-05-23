#!/usr/bin/env bash
set -euo pipefail

# resolve-write-path.sh <slug> <channel> [--mkdir]
#
# Prints the canonical WRITE destination for a persona channel file. Unlike the
# read-side resolver (resolve-persona.sh, first-hit-wins across four paths), an
# author needs ONE unambiguous place to write. The chain is therefore only two
# deep, env override first, XDG default second:
#
#   1. $STONEMATT_SKILLS_CONFIG/persona/<slug>/<channel>.md   (env override)
#   2. ${XDG_CONFIG_HOME:-$HOME/.config}/stonematt-skills/persona/<slug>/<channel>.md
#
# Both targets are PRIVATE (outside this public repo). When the XDG path is a
# stow symlink into a dotfiles source, writing through it lands the edit in the
# version-controlled dotfiles tree — which is what we want.
#
# Never resolves into $SKILL_DIR or cwd: those are read-only fixture/bundle
# locations, not author destinations.
#
# Prints the destination path on stdout, exits 0. With --mkdir, creates the
# parent directory first.

if [ $# -lt 2 ]; then
  echo "usage: $0 <slug> <channel> [--mkdir]" >&2
  exit 64
fi

slug="$1"
channel="$2"
mkdir_flag=0
if [ "${3:-}" = "--mkdir" ]; then
  mkdir_flag=1
fi

if ! [[ "$slug" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "error: slug must be lowercase letters/digits/hyphens, starting with a letter (got: '$slug')" >&2
  exit 1
fi

if [ -n "${STONEMATT_SKILLS_CONFIG:-}" ]; then
  dest="$STONEMATT_SKILLS_CONFIG/persona/$slug/$channel.md"
else
  xdg="${XDG_CONFIG_HOME:-$HOME/.config}"
  dest="$xdg/stonematt-skills/persona/$slug/$channel.md"
fi

if [ "$mkdir_flag" -eq 1 ]; then
  mkdir -p "$(dirname "$dest")"
fi

printf '%s\n' "$dest"
