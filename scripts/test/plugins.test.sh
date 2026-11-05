#!/usr/bin/env bash
set -euo pipefail

# Validates and tests every mod in the repo: a plugin folder under skills/ with
# a hooks module (hooks/hooks.json). Needs the claude CLI; without it, says so
# and passes, so CI without Claude Code still runs the rest of the suite.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

mods=()
while IFS= read -r -d '' hooks; do
  mods+=("$(dirname "$(dirname "$hooks")")")
done < <(find "$REPO/skills" -path '*/hooks/hooks.json' -not -path '*/node_modules/*' -print0 | sort -z)

if [ "${#mods[@]}" -eq 0 ]; then
  echo "plugin tests: no mods found"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "plugin tests: SKIP (claude CLI not installed): ${#mods[@]} mod(s) unchecked"
  exit 0
fi

pass=0
fail=0
for mod in "${mods[@]}"; do
  name="${mod#"$REPO"/}"
  if claude plugin validate "$mod" >/dev/null 2>&1; then
    echo "PASS: validate $name"; pass=$((pass + 1))
  else
    echo "FAIL: validate $name (run: claude plugin validate $name)"; fail=$((fail + 1))
  fi
  if [ -n "$(find "$mod" -name '*.test.ts' -o -name '*.test.tsx' | head -1)" ]; then
    if claude plugin test "$mod" >/dev/null 2>&1; then
      echo "PASS: test $name"; pass=$((pass + 1))
    else
      echo "FAIL: test $name (run: claude plugin test $name)"; fail=$((fail + 1))
    fi
  fi
done

echo
echo "plugin tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
