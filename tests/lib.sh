#!/usr/bin/env bash
# Shared test helpers for journal-sweep tests.
# Source this; it defines assert_* and a tally that exits nonzero on any failure.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../scripts" && pwd)"

_PASS=0
_FAIL=0

_ok()   { printf '  ok   %s\n' "$1"; _PASS=$((_PASS+1)); }
_bad()  { printf '  FAIL %s\n' "$1"; _FAIL=$((_FAIL+1)); }

assert_eq() { # expected actual msg
  if [ "$1" = "$2" ]; then _ok "$3"; else _bad "$3 (expected [$1] got [$2])"; fi
}
assert_contains() { # haystack needle msg
  case "$1" in *"$2"*) _ok "$3";; *) _bad "$3 (missing [$2])";; esac
}
assert_not_contains() { # haystack needle msg
  case "$1" in *"$2"*) _bad "$3 (unexpected [$2])";; *) _ok "$3";; esac
}
assert_file() { # path msg
  if [ -f "$1" ]; then _ok "$2"; else _bad "$2 (no file $1)"; fi
}
assert_nofile() { # path msg
  if [ -f "$1" ]; then _bad "$2 (file exists $1)"; else _ok "$2"; fi
}
assert_le() { # a b msg  -> a <= b
  if [ "$1" -le "$2" ]; then _ok "$3"; else _bad "$3 ($1 > $2)"; fi
}

finish() { # name
  echo "---- $1: $_PASS passed, $_FAIL failed ----"
  [ "$_FAIL" -eq 0 ]
}
