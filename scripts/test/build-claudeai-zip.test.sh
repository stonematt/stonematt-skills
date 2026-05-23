#!/usr/bin/env bash
set -uo pipefail

# Black-box test for scripts/build-claudeai-zip.sh. Bundles the voice skill plus
# a throwaway persona, then asserts the zip layout matches Resolver path 3
# ($SKILL_DIR/persona/<slug>/voice.md).
#
# Run: ./scripts/test/build-claudeai-zip.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
builder="$repo/scripts/build-claudeai-zip.sh"

pass=0
fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

# --- Case 1: voice + persona bundle has the expected layout ---
(
  cfg="$(mktemp -d)"; trap 'rm -rf "$cfg"; rm -f "$repo/stonematt-voice-demo.zip"' EXIT
  mkdir -p "$cfg/persona/demo"
  printf '# demo voice\n' >"$cfg/persona/demo/voice.md"

  STONEMATT_SKILLS_CONFIG="$cfg" "$builder" voice demo >/dev/null 2>&1
  zip="$repo/stonematt-voice-demo.zip"
  [ -f "$zip" ] || exit 1
  listing="$(unzip -l "$zip")"
  grep -q "SKILL.md" <<<"$listing" \
    && grep -q "scripts/resolve-persona.sh" <<<"$listing" \
    && grep -q "persona/demo/voice.md" <<<"$listing"
) && ok "bundle contains SKILL.md, resolver script, and persona/demo/voice.md" \
   || bad "voice+persona bundle" "missing expected entries in zip"

# --- Case 2: missing persona errors with a scaffold hint ---
(
  cfg="$(mktemp -d)"; trap 'rm -rf "$cfg"; rm -f "$repo/stonematt-voice-absent.zip"' EXIT
  out="$(STONEMATT_SKILLS_CONFIG="$cfg" "$builder" voice absent 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && grep -q "persona-init" <<<"$out"
) && ok "missing persona errors with persona-init hint" \
   || bad "missing persona" "did not error or no hint"

# --- Case 3: unknown skill errors ---
(
  out="$("$builder" no-such-skill 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && grep -q "not found" <<<"$out"
) && ok "unknown skill errors clearly" \
   || bad "unknown skill" "did not error"

echo
printf 'bundle builder tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
