#!/usr/bin/env bash
#
# install.sh — manage the journal-sweep launchd agent (macOS).
#
# Usage:
#   ./install.sh install      copy plist to ~/Library/LaunchAgents and (re)load it
#   ./install.sh uninstall    unload and remove the plist
#   ./install.sh run          run the sweep now (kickstart) — for testing
#   ./install.sh status       show whether the agent is loaded + next run
#   ./install.sh dry          run a read-only detection pass (no dispatch, no cost)
#
# Idempotent: `install` reloads cleanly if the agent is already loaded.
set -euo pipefail

LABEL="com.stonematt.journal-sweep"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/${LABEL}.plist"
DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"
DOMAIN="gui/$(id -u)"
TARGET="$DOMAIN/$LABEL"
SWEEP="$(cd "$HERE/.." && pwd)/scripts/journal-sweep.sh"

cmd="${1:-install}"
case "$cmd" in
  install)
    [ -f "$SRC" ] || { echo "ERROR: plist not found: $SRC" >&2; exit 1; }
    plutil -lint "$SRC" >/dev/null || { echo "ERROR: plist failed lint" >&2; exit 1; }
    mkdir -p "$HOME/Library/LaunchAgents"
    cp "$SRC" "$DEST"
    launchctl bootout "$TARGET" 2>/dev/null || true   # unload if already loaded
    launchctl bootstrap "$DOMAIN" "$DEST"
    launchctl enable "$TARGET" 2>/dev/null || true
    echo "loaded: $TARGET"
    echo "next run 00:30 daily. test now with: $0 run"
    ;;
  uninstall)
    launchctl bootout "$TARGET" 2>/dev/null || true
    rm -f "$DEST"
    echo "unloaded + removed: $TARGET"
    ;;
  run|kickstart)
    launchctl kickstart -k "$TARGET" 2>/dev/null \
      || { echo "agent not loaded — run '$0 install' first" >&2; exit 1; }
    echo "kickstarted. tail the log:"
    echo "  tail -f ~/Library/Logs/journal-sweep.log"
    ;;
  status)
    if launchctl print "$TARGET" >/dev/null 2>&1; then
      launchctl print "$TARGET" | grep -E 'state|program|runs|last exit' || true
    else
      echo "not loaded."
    fi
    ;;
  dry)
    exec bash "$SWEEP" --dry-run
    ;;
  *)
    sed -n '3,12p' "${BASH_SOURCE[0]}"
    exit 2
    ;;
esac
