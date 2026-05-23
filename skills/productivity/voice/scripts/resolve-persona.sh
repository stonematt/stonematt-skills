#!/usr/bin/env bash
set -euo pipefail

# resolve-persona.sh <slug> <channel>
#
# Resolves a persona channel file via the 4-path chain (first hit wins):
#   1. $STONEMATT_SKILLS_CONFIG/persona/<slug>/<channel>.md   (env override)
#   2. ${XDG_CONFIG_HOME:-$HOME/.config}/stonematt-skills/persona/<slug>/<channel>.md
#   3. $SKILL_DIR/persona/<slug>/<channel>.md                 (claude.ai bundle)
#   4. ./persona/<slug>/<channel>.md                          (cwd / dev fixture)
#
# SKILL_DIR is derived as the parent of this script's dir, so it points at the
# skill root where persona/ sits inside an uploaded claude.ai bundle.
#
# On a hit: prints the resolved path to stdout, exits 0.
# On no hit: prints all attempted paths (annotating env-unset rules) to stderr,
# exits 1. See ADR-0001.

if [ $# -lt 2 ]; then
  echo "usage: $0 <slug> <channel>" >&2
  exit 64
fi

slug="$1"
channel="$2"

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xdg="${XDG_CONFIG_HOME:-$HOME/.config}"

# Path 1 is only checkable when the env override is set; record its status for
# the no-hit error so the user can tell misconfiguration from missing content.
if [ -n "${STONEMATT_SKILLS_CONFIG:-}" ]; then
  p1="$STONEMATT_SKILLS_CONFIG/persona/$slug/$channel.md"
  p1_note=""
else
  p1="\$STONEMATT_SKILLS_CONFIG/persona/$slug/$channel.md"
  p1_note="  (env unset — skipped)"
fi
p2="$xdg/stonematt-skills/persona/$slug/$channel.md"
p3="$skill_dir/persona/$slug/$channel.md"
p4="./persona/$slug/$channel.md"

if [ -n "${STONEMATT_SKILLS_CONFIG:-}" ] && [ -f "$p1" ]; then printf '%s\n' "$p1"; exit 0; fi
if [ -f "$p2" ]; then printf '%s\n' "$p2"; exit 0; fi
if [ -f "$p3" ]; then printf '%s\n' "$p3"; exit 0; fi
if [ -f "$p4" ]; then printf '%s\n' "$p4"; exit 0; fi

{
  echo "error: no persona file found for slug='$slug' channel='$channel'"
  echo "attempted (in order, first hit wins):"
  echo "  1. $p1$p1_note"
  echo "  2. $p2"
  echo "  3. $p3"
  echo "  4. $p4"
} >&2
exit 1
