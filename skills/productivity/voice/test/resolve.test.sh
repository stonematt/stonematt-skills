#!/usr/bin/env bash
set -uo pipefail

# Black-box tests for the persona Resolver. No framework — bash + grep on output.
# Covers all 4 paths (env, XDG, $SKILL_DIR, cwd), first-hit-wins, and no-hit.
#
# Run: ./skills/productivity/voice/test/resolve.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "$here/.." && pwd)"
resolver="$skill_dir/scripts/resolve-persona.sh"

pass=0
fail=0
ok()   { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

# Each case runs in a clean env from a clean cwd so only the path under test hits.
# We isolate by unsetting the env override and pointing XDG at an empty dir,
# then running from a tmp cwd with no ./persona — overriding per case as needed.

make_persona() { # <root> <slug> <channel> -> writes a file, prints its dir-root
  local root="$1" slug="$2" channel="$3"
  mkdir -p "$root/persona/$slug"
  printf 'fixture: %s/%s\n' "$slug" "$channel" > "$root/persona/$slug/$channel.md"
}

# --- Case 1: env override ($STONEMATT_SKILLS_CONFIG) wins ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  envroot="$tmp/env"; xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  make_persona "$envroot" alpha voice
  mkdir -p "$xdgroot/stonematt-skills" "$cwd"
  out="$(cd "$cwd" && STONEMATT_SKILLS_CONFIG="$envroot" XDG_CONFIG_HOME="$xdgroot" "$resolver" alpha voice 2>/dev/null)"
  [ "$out" = "$envroot/persona/alpha/voice.md" ]
) && ok "env override resolves to \$STONEMATT_SKILLS_CONFIG" \
   || bad "env override" "did not resolve to the env path"

# --- Case 2: XDG default ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  make_persona "$xdgroot/stonematt-skills" beta voice
  mkdir -p "$cwd"
  out="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" beta voice 2>/dev/null)"
  [ "$out" = "$xdgroot/stonematt-skills/persona/beta/voice.md" ]
) && ok "XDG default resolves under \$XDG_CONFIG_HOME/stonematt-skills" \
   || bad "XDG default" "did not resolve to the XDG path"

# --- Case 3: $SKILL_DIR bundle (slug=test ships in the skill dir) ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  mkdir -p "$xdgroot/stonematt-skills" "$cwd"   # XDG present but empty
  out="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" test voice 2>/dev/null)"
  [ "$out" = "$skill_dir/persona/test/voice.md" ]
) && ok "\$SKILL_DIR bundle resolves the shipped test fixture" \
   || bad "\$SKILL_DIR bundle" "did not resolve to the skill-dir fixture"

# --- Case 4: cwd relative ./persona ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  make_persona "$cwd" gamma voice
  mkdir -p "$xdgroot/stonematt-skills"
  out="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" gamma voice 2>/dev/null)"
  [ "$out" = "./persona/gamma/voice.md" ]
) && ok "cwd relative resolves ./persona" \
   || bad "cwd relative" "did not resolve to ./persona"

# --- Case 5: first-hit-wins (env beats XDG when both present) ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  envroot="$tmp/env"; xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  make_persona "$envroot" delta voice
  make_persona "$xdgroot/stonematt-skills" delta voice
  mkdir -p "$cwd"
  out="$(cd "$cwd" && STONEMATT_SKILLS_CONFIG="$envroot" XDG_CONFIG_HOME="$xdgroot" "$resolver" delta voice 2>/dev/null)"
  [ "$out" = "$envroot/persona/delta/voice.md" ]
) && ok "first-hit-wins: env beats XDG" \
   || bad "first-hit-wins" "XDG won when env should have"

# --- Case 6: no hit errors clearly and cites all 4 paths ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  mkdir -p "$xdgroot/stonematt-skills" "$cwd"
  err="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" nope voice 2>&1 >/dev/null)"
  rc=$?
  [ "$rc" -ne 0 ] \
    && grep -q "no persona file found" <<<"$err" \
    && grep -q "STONEMATT_SKILLS_CONFIG" <<<"$err" \
    && grep -q "env unset" <<<"$err" \
    && grep -q "stonematt-skills/persona/nope/voice.md" <<<"$err" \
    && grep -q "./persona/nope/voice.md" <<<"$err"
) && ok "no-hit errors non-zero and cites all 4 paths" \
   || bad "no-hit" "missing error text, exit code, or path citations"

echo
printf 'resolver tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
