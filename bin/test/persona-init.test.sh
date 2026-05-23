#!/usr/bin/env bash
set -uo pipefail

# Black-box tests for bin/persona-init. No framework — bash + grep on output
# and on the files it writes into a throwaway dotfiles tree.
#
# Run: ./bin/test/persona-init.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init="$(cd "$here/.." && pwd)/persona-init"

pass=0
fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

# Build a throwaway dotfiles root with the required stow package present.
new_dotfiles() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/stonematt-skills"
  printf '%s' "$d"
}

# --- Case 1: fresh scaffold writes persona + shim with hybrid-shape headers ---
(
  df="$(new_dotfiles)"; trap 'rm -rf "$df"' EXIT
  STONEMATT_DOTFILES_DIR="$df" "$init" demo >/dev/null 2>&1
  persona="$df/stonematt-skills/dot-config/stonematt-skills/persona/demo/voice.md"
  shim="$df/stonematt-skills/dot-claude/skills/demo-voice/SKILL.md"
  [ -f "$persona" ] && [ -f "$shim" ] \
    && grep -q "## Style rules" "$persona" \
    && grep -q "## Few-shot examples" "$persona" \
    && grep -q "## Anti-patterns" "$persona" \
    && grep -q "name: demo-voice" "$shim" \
    && grep -q -- "--persona demo" "$shim"
) && ok "fresh scaffold writes persona + shim with hybrid headers" \
   || bad "fresh scaffold" "missing files, headers, or shim binding"

# --- Case 2: idempotent re-run does not overwrite ---
(
  df="$(new_dotfiles)"; trap 'rm -rf "$df"' EXIT
  persona="$df/stonematt-skills/dot-config/stonematt-skills/persona/demo/voice.md"
  STONEMATT_DOTFILES_DIR="$df" "$init" demo >/dev/null 2>&1
  printf 'EDITED BY USER\n' >>"$persona"
  before="$(cat "$persona")"
  out="$(STONEMATT_DOTFILES_DIR="$df" "$init" demo 2>&1)"
  after="$(cat "$persona")"
  [ "$before" = "$after" ] && grep -q "skip (exists)" <<<"$out"
) && ok "re-run is a no-op (idempotent, preserves edits)" \
   || bad "idempotent re-run" "file changed or no skip message"

# --- Case 3: --dry-run writes nothing ---
(
  df="$(new_dotfiles)"; trap 'rm -rf "$df"' EXIT
  out="$(STONEMATT_DOTFILES_DIR="$df" "$init" ghost --dry-run 2>&1)"
  persona="$df/stonematt-skills/dot-config/stonematt-skills/persona/ghost/voice.md"
  shim="$df/stonematt-skills/dot-claude/skills/ghost-voice/SKILL.md"
  [ ! -e "$persona" ] && [ ! -e "$shim" ] \
    && grep -q "would write" <<<"$out" \
    && grep -q "dry run" <<<"$out"
) && ok "--dry-run writes nothing" \
   || bad "--dry-run" "files appeared or missing dry-run notice"

# --- Case 4: missing STONEMATT_DOTFILES_DIR errors non-zero ---
(
  out="$(env -u STONEMATT_DOTFILES_DIR "$init" demo 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && grep -q "STONEMATT_DOTFILES_DIR" <<<"$out"
) && ok "missing STONEMATT_DOTFILES_DIR errors clearly" \
   || bad "missing dotfiles env" "did not error or no hint"

# --- Case 5: invalid slug rejected ---
(
  df="$(new_dotfiles)"; trap 'rm -rf "$df"' EXIT
  out="$(STONEMATT_DOTFILES_DIR="$df" "$init" "Bad_Slug" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && grep -q "slug must be" <<<"$out"
) && ok "invalid slug rejected" \
   || bad "invalid slug" "accepted a bad slug"

echo
printf 'persona-init tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
