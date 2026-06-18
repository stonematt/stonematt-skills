#!/usr/bin/env bash
# Phase 0 HARD GATE — validates that the headless skill invocation actually works:
#   claude -p "/stone-journal for <D> through <D>" --model sonnet --permission-mode bypassPermissions
#
# Spends real tokens and runs an UNATTENDED agent (bypassPermissions). Not part
# of run-all.sh. Run once, when you've authorized headless claude:
#   bash tests/phase0-smoke.sh            # targets yesterday
#   bash tests/phase0-smoke.sh 2026-06-17 # explicit date
#
# If this is RED, the whole unattended design needs rethinking — stop and report.
set -uo pipefail

SETUP="${HOME}/.claude/skills/stone-journal/scripts/journal-setup.sh"
TARGET="${1:-$(date -j -v-1d +%F)}"
SANDBOX="$(mktemp -d)/repo"; mkdir -p "$SANDBOX"; cd "$SANDBOX"

git init -q -b main
git config user.email phase0@test.local
git config user.name  "Phase0"
echo hello > a.txt; git add a.txt
GIT_AUTHOR_DATE="${TARGET}T12:00:00" GIT_COMMITTER_DATE="${TARGET}T12:00:00" \
  git commit -q -m "feat: work on $TARGET"

bash "$SETUP" "$SANDBOX" || { echo "FAIL: journal-setup"; exit 2; }

echo "== invoking headless /stone-journal for $TARGET (real claude) =="
timeout 300 claude -p "/stone-journal for $TARGET through $TARGET" \
  --model sonnet --permission-mode bypassPermissions
rc=$?

ENTRY="$SANDBOX/.journal/docs/journal/${TARGET}.md"
fail=0
[ "$rc" -eq 0 ]                                   && echo "PASS exit 0"        || { echo "FAIL exit=$rc"; fail=1; }
[ -f "$ENTRY" ]                                   && echo "PASS entry exists"  || { echo "FAIL no entry $ENTRY"; fail=1; }
grep -qE "^date: *${TARGET}" "$ENTRY" 2>/dev/null && echo "PASS date stamp"    || { echo "FAIL date frontmatter"; fail=1; }

echo "----"
[ "$fail" -eq 0 ] && echo "PHASE0: GREEN" || echo "PHASE0: RED"
exit "$fail"
