#!/usr/bin/env bash
# Phase 5 test: launchd plist is valid and correctly configured, and the suite
# never loads it. A user who opted in via launchd/install.sh may have it loaded.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PLIST="$(cd "$TESTS_DIR/.." && pwd)/launchd/com.stonematt.journal-sweep.plist"
assert_file "$PLIST" "plist exists"

plutil -lint "$PLIST" >/dev/null 2>&1 && _ok "plutil -lint valid" || _bad "plutil -lint valid"

ext() { plutil -extract "$1" raw -o - "$PLIST" 2>/dev/null; }
assert_eq "com.stonematt.journal-sweep" "$(ext Label)" "Label correct"
assert_eq "0"  "$(ext StartCalendarInterval.Hour)"   "schedule hour = 0"
assert_eq "30" "$(ext StartCalendarInterval.Minute)" "schedule minute = 30"
assert_contains "$(ext StandardOutPath)" "journal-sweep.log" "stdout -> log file"
assert_contains "$(ext ProgramArguments.1)" "journal-sweep.sh" "runs journal-sweep.sh"
assert_eq "false" "$(ext RunAtLoad)" "RunAtLoad false (calendar-only)"

# Make sure *the tests* didn't load it. Loading is the user's call, made by
# running launchd/install.sh, which copies the plist to ~/Library/LaunchAgents.
# The tests never write there, so that file is the signal that a running agent
# was opted into rather than started by accident.
INSTALLED="$HOME/Library/LaunchAgents/com.stonematt.journal-sweep.plist"
if ! launchctl list 2>/dev/null | grep -q 'com.stonematt.journal-sweep'; then
  _ok "agent not loaded (tests did not load it)"
elif [ -f "$INSTALLED" ]; then
  _ok "agent loaded from an installed plist (user opted in)"
else
  _bad "agent loaded with no installed plist — something loaded it transiently"
fi

finish "plist"
