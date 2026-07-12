#!/usr/bin/env bash
# AFK gate: run the full deterministic test suite. Nonzero exit on any failure.
#
# NOTE: Phase 0 (real headless `claude -p /stone-journal`) is NOT included here —
# it spends tokens and needs permission to run an unattended agent. Run it
# separately once authorized:  bash tests/phase0-smoke.sh
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUITE="config detector dispatch outputs lock plist e2e pocock-plan pocock-bind pocock-slots pocock-apply pocock-preflight pocock-migrant pocock-board pocock-member"
fail=0
for t in $SUITE; do
  echo "=================== test-$t ==================="
  if bash "$TESTS_DIR/test-$t.sh"; then :; else fail=1; fi
done

echo "==============================================="
if [ "$fail" -eq 0 ]; then echo "ALL GREEN ✅"; else echo "SOME RED ❌"; fi
exit "$fail"
