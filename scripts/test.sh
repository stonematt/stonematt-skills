#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

"$REPO/scripts/test/validate-skills.test.sh"
"$REPO/scripts/test/build-claudeai-zip.test.sh"
