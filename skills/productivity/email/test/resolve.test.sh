#!/usr/bin/env bash
set -uo pipefail

# Black-box tests for the email skill's bundled Resolver. Same resolver contract
# as the voice skill, exercised on the `email` channel, plus a check that both
# channels (email + voice) resolve from the shipped test fixture. No framework.
#
# Run: ./skills/productivity/email/test/resolve.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "$here/.." && pwd)"
resolver="$skill_dir/scripts/resolve-persona.sh"

pass=0
fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

make_persona() { # <root> <slug> <channel>
  local root="$1" slug="$2" channel="$3"
  mkdir -p "$root/persona/$slug"
  printf 'fixture: %s/%s\n' "$slug" "$channel" > "$root/persona/$slug/$channel.md"
}

# --- Case 1: env override resolves the email channel ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  envroot="$tmp/env"; xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  make_persona "$envroot" alpha email
  mkdir -p "$xdgroot/stonematt-skills" "$cwd"
  out="$(cd "$cwd" && STONEMATT_SKILLS_CONFIG="$envroot" XDG_CONFIG_HOME="$xdgroot" "$resolver" alpha email 2>/dev/null)"
  [ "$out" = "$envroot/persona/alpha/email.md" ]
) && ok "env override resolves email channel" \
   || bad "env override (email)" "did not resolve to the env path"

# --- Case 2: XDG default resolves the email channel ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  make_persona "$xdgroot/stonematt-skills" beta email
  mkdir -p "$cwd"
  out="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" beta email 2>/dev/null)"
  [ "$out" = "$xdgroot/stonematt-skills/persona/beta/email.md" ]
) && ok "XDG default resolves email channel" \
   || bad "XDG default (email)" "did not resolve to the XDG path"

# --- Case 3: shipped fixture resolves BOTH channels from $SKILL_DIR ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  mkdir -p "$xdgroot/stonematt-skills" "$cwd"
  e="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" test email 2>/dev/null)"
  v="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" test voice 2>/dev/null)"
  [ "$e" = "$skill_dir/persona/test/email.md" ] && [ "$v" = "$skill_dir/persona/test/voice.md" ]
) && ok "shipped fixture resolves both email + voice channels" \
   || bad "bundle both channels" "email and/or voice did not resolve from \$SKILL_DIR"

# --- Case 4: first-hit-wins on email channel (env beats XDG) ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  envroot="$tmp/env"; xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  make_persona "$envroot" delta email
  make_persona "$xdgroot/stonematt-skills" delta email
  mkdir -p "$cwd"
  out="$(cd "$cwd" && STONEMATT_SKILLS_CONFIG="$envroot" XDG_CONFIG_HOME="$xdgroot" "$resolver" delta email 2>/dev/null)"
  [ "$out" = "$envroot/persona/delta/email.md" ]
) && ok "first-hit-wins on email: env beats XDG" \
   || bad "first-hit-wins (email)" "XDG won when env should have"

# --- Case 5: no hit errors clearly and cites the email channel ---
(
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  xdgroot="$tmp/xdg"; cwd="$tmp/cwd"
  mkdir -p "$xdgroot/stonematt-skills" "$cwd"
  err="$(cd "$cwd" && unset STONEMATT_SKILLS_CONFIG; XDG_CONFIG_HOME="$xdgroot" "$resolver" nope email 2>&1 >/dev/null)"
  rc=$?
  [ "$rc" -ne 0 ] \
    && grep -q "no persona file found" <<<"$err" \
    && grep -q "channel='email'" <<<"$err" \
    && grep -q "stonematt-skills/persona/nope/email.md" <<<"$err"
) && ok "no-hit on email errors non-zero and cites the channel" \
   || bad "no-hit (email)" "missing error text, exit code, or channel citation"

echo
printf 'email resolver tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
