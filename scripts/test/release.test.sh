#!/usr/bin/env bash
set -uo pipefail

# Black-box test for scripts/release.sh. Builds a throwaway git repo, copies in
# release.sh, and exercises the guards. Never touches the real repo, never
# pushes, never creates a real GitHub Release (always uses --dry-run for the
# success path).
#
# Run: ./scripts/test/release.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
release_src="$repo/scripts/release.sh"

pass=0
fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

# --- build a fixture repo --------------------------------------------------
fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT

mkdir -p "$fix/.claude-plugin" "$fix/scripts"
cp "$release_src" "$fix/scripts/release.sh"
printf '{\n  "name": "fixture",\n  "version": "9.9.9"\n}\n' > "$fix/.claude-plugin/plugin.json"
cat > "$fix/CHANGELOG.md" <<'EOF'
# Changelog

## [9.9.9] - 2026-01-01

### Added
- fixture release note line.

## [9.9.8] - 2025-12-01

### Added
- older note.

[9.9.9]: https://example.com/compare/v9.9.8...v9.9.9
[9.9.8]: https://example.com/releases/tag/v9.9.8
EOF

git -C "$fix" init -q
git -C "$fix" config user.email test@example.com
git -C "$fix" config user.name "Test"
git -C "$fix" add -A
git -C "$fix" commit -qm "init"
git -C "$fix" branch -M main

run() { ( cd "$fix" && ./scripts/release.sh "$@" 2>&1 ); }

# --- Case 1: refuses off main ---------------------------------------------
git -C "$fix" checkout -q -b feat/x
out="$(run --dry-run)"; rc=$?
{ [ "$rc" -ne 0 ] && grep -q "must release from 'main'" <<<"$out"; } \
  && ok "refuses to release off main" \
  || bad "off-main guard" "rc=$rc out=$out"
git -C "$fix" checkout -q main

# --- Case 2: dry-run on main succeeds, emits notes, creates no tag --------
out="$(run --dry-run)"; rc=$?
{ [ "$rc" -eq 0 ] \
    && grep -q "fixture release note line." <<<"$out" \
    && ! grep -q "older note." <<<"$out" \
    && ! grep -q "example.com" <<<"$out" \
    && [ -z "$(git -C "$fix" tag --list 'v9.9.9')" ]; } \
  && ok "dry-run succeeds, extracts only this version's notes (no older section, no link refs), no tag made" \
  || bad "dry-run happy path" "rc=$rc tags=[$(git -C "$fix" tag --list)] out=$out"

# --- Case 3: dirty tree blocks --------------------------------------------
echo dirt > "$fix/dirty.txt"
out="$(run --dry-run)"; rc=$?
{ [ "$rc" -ne 0 ] && grep -q "working tree not clean" <<<"$out"; } \
  && ok "blocks on dirty working tree" \
  || bad "dirty-tree guard" "rc=$rc out=$out"
rm -f "$fix/dirty.txt"

# --- Case 4: missing CHANGELOG section blocks -----------------------------
printf '{\n  "name": "fixture",\n  "version": "7.7.7"\n}\n' > "$fix/.claude-plugin/plugin.json"
git -C "$fix" commit -qam "bump to unlisted version"
out="$(run --dry-run)"; rc=$?
{ [ "$rc" -ne 0 ] && grep -q "no '## \[7.7.7\]' section" <<<"$out"; } \
  && ok "blocks when CHANGELOG lacks the version section" \
  || bad "changelog guard" "rc=$rc out=$out"

# --- Case 5: existing tag blocks ------------------------------------------
printf '{\n  "name": "fixture",\n  "version": "9.9.9"\n}\n' > "$fix/.claude-plugin/plugin.json"
git -C "$fix" commit -qam "back to 9.9.9"  # clean tree on a listed version
git -C "$fix" tag v9.9.9
out="$(run --dry-run)"; rc=$?
{ [ "$rc" -ne 0 ] && grep -q "already exists" <<<"$out"; } \
  && ok "blocks when tag already exists" \
  || bad "existing-tag guard" "rc=$rc out=$out"

echo
printf 'release tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
