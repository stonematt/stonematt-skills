#!/usr/bin/env bash
# Phase 5 test: launchd plist is valid and correctly configured. Never loaded.
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

# Make sure we didn't accidentally load it.
if launchctl list 2>/dev/null | grep -q 'com.stonematt.journal-sweep'; then
  _bad "agent is NOT loaded (must stay unloaded until user opts in)"
else
  _ok "agent is NOT loaded (correct — user loads it)"
fi

finish "plist"
