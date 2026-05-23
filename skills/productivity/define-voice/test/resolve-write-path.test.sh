#!/usr/bin/env bash
set -uo pipefail

# Black-box tests for the define-voice write-path resolver. No framework —
# bash + grep on output. Covers env override, XDG default, env-beats-XDG,
# --mkdir, and slug validation.
#
# Run: ./skills/productivity/define-voice/test/resolve-write-path.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "$here/.." && pwd)"
resolver="$skill_dir/scripts/resolve-write-path.sh"

pass=0
fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

# --- Case 1: env override wins ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  envroot="$tmp/env"; xdgroot="$tmp/xdg"
  out="$(STONEMATT_SKILLS_CONFIG="$envroot" XDG_CONFIG_HOME="$xdgroot" "$resolver" alpha voice 2>/dev/null)"
  [ "$out" = "$envroot/persona/alpha/voice.md" ]
) && ok "env override targets \$STONEMATT_SKILLS_CONFIG" \
   || bad "env override" "did not target the env path"

# --- Case 2: XDG default when env unset ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"
  out="$(unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" beta voice 2>/dev/null)"
  [ "$out" = "$xdgroot/stonematt-skills/persona/beta/voice.md" ]
) && ok "XDG default targets \$XDG_CONFIG_HOME/stonematt-skills" \
   || bad "XDG default" "did not target the XDG path"

# --- Case 3: env beats XDG when both set ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  envroot="$tmp/env"; xdgroot="$tmp/xdg"
  out="$(STONEMATT_SKILLS_CONFIG="$envroot" XDG_CONFIG_HOME="$xdgroot" "$resolver" gamma voice 2>/dev/null)"
  [ "$out" = "$envroot/persona/gamma/voice.md" ]
) && ok "env beats XDG" \
   || bad "env-beats-XDG" "XDG won when env should have"

# --- Case 4: --mkdir creates the parent dir; without it, no dir is made ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"
  # without --mkdir: parent must NOT exist
  out="$(unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" delta voice 2>/dev/null)"
  [ ! -d "$(dirname "$out")" ] || exit 1
  # with --mkdir: parent must exist afterward
  out2="$(unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" delta voice --mkdir 2>/dev/null)"
  [ -d "$(dirname "$out2")" ]
) && ok "--mkdir creates parent dir; default does not" \
   || bad "--mkdir" "directory creation behavior wrong"

# --- Case 5: invalid slug errors non-zero ---
(
  out="$("$resolver" "Bad_Slug" voice 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && grep -q "slug must be lowercase" <<<"$out"
) && ok "invalid slug rejected" \
   || bad "slug validation" "did not reject an invalid slug"

# --- Case 6: never targets the public repo / cwd ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"
  out="$(cd "$skill_dir" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" epsilon voice 2>/dev/null)"
  case "$out" in
    "$skill_dir"/*|./*) exit 1 ;;   # must not land in the repo or relative cwd
    "$xdgroot"/*) : ;;
    *) exit 1 ;;
  esac
) && ok "write path stays outside the public repo" \
   || bad "private destination" "resolved into the repo or cwd"

echo
printf 'write-path tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
