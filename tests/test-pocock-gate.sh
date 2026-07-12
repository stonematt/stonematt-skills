#!/usr/bin/env bash
# AFK-gate entry for TEST SEAM 1 (#66). Runs the acceptance gate + behavioral
# smoke harness in OFFLINE self-verify mode ONLY — it forces POCOCK_SMOKE_LIVE
# off so run-all can NEVER trigger the live smoke (which needs network +
# authorization and mutates a real tracker). The deterministic offline pass
# proves the gate PASSES a good adoption, FAILS LOUDLY on each single miss, and
# that the behavioral smoke's cleanup is guaranteed even on a mid-smoke crash.
#
# The real, live smoke is what /stone-adopt-pocock runs at adoption time:
#   POCOCK_SMOKE_LIVE=1 POCOCK_TARGET_REPO=... POCOCK_SMOKE_REPO=owner/repo \
#     bash tests/pocock-acceptance-gate.sh
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POCOCK_SMOKE_LIVE=0 exec bash "$TESTS_DIR/pocock-acceptance-gate.sh"
