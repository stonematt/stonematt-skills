#!/usr/bin/env bash
set -uo pipefail

# Black-box test for scripts/build-claudeai-zip.sh. Builds a real skill and
# asserts the zip places the skill folder at the zip root — the layout the
# claude.ai uploader (Settings → Customize → Skills) expects.
#
# Run: ./scripts/test/build-claudeai-zip.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
builder="$repo/scripts/build-claudeai-zip.sh"

pass=0
fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

# --- Case 1: zip has the skill folder at the root ---
(
  trap 'rm -f "$repo/stone-commit.zip"' EXIT
  "$builder" stone-commit >/dev/null 2>&1 || exit 1
  zip="$repo/stone-commit.zip"
  [ -f "$zip" ] || exit 1
  unzip -l "$zip" | grep -q "stone-commit/SKILL.md"
) && ok "zip contains stone-commit/ at the root" \
   || bad "folder-at-root layout" "stone-commit/SKILL.md not found in zip"

# --- Case 2: unknown skill errors clearly ---
(
  out="$("$builder" no-such-skill 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && grep -q "not found" <<<"$out"
) && ok "unknown skill errors clearly" \
   || bad "unknown skill" "did not error"

echo
printf 'bundle builder tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
