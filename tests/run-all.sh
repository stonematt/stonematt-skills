#!/usr/bin/env bash
# AFK gate: run the full deterministic test suite. Nonzero exit on any failure.
#
# NOTE: Phase 0 (real headless `claude -p /stone-journal`) is NOT included here —
# it spends tokens and needs permission to run an unattended agent. Run it
# separately once authorized:  bash tests/phase0-smoke.sh
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# pocock-board is parked: it still couples to the now-deleted pocock-plan.sh
# emitter for board_scope detection. #62 refactors pocock-board.sh down to the
# single Projects-v2 GraphQL helper and re-enables `pocock-board` here with a
# refocused, offline test.
SUITE="config detector dispatch outputs lock plist e2e"
fail=0
for t in $SUITE; do
  echo "=================== test-$t ==================="
  if bash "$TESTS_DIR/test-$t.sh"; then :; else fail=1; fi
done

echo "==============================================="
if [ "$fail" -eq 0 ]; then echo "ALL GREEN ✅"; else echo "SOME RED ❌"; fi
exit "$fail"
