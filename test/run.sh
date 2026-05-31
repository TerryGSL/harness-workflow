#!/usr/bin/env bash
# Minimal zero-dependency test harness. Runs every test-*.sh in this dir.
# Each test-*.sh sources this file's helpers via: source "$(dirname "$0")/run.sh" --lib
set -uo pipefail

if [ "${1:-}" = "--lib" ]; then
  # ---- library mode: provide assert helpers to a test file ----
  # Ensure HW_ROOT is set even when a test-*.sh is run standalone (not via the runner).
  HW_ROOT="${HW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"; export HW_ROOT
  _T_PASS=0; _T_FAIL=0
  assert() { # assert <desc> <cmd...>  (passes if cmd exits 0)
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "  ✓ $desc"; _T_PASS=$((_T_PASS+1));
    else echo "  ✗ $desc"; _T_FAIL=$((_T_FAIL+1)); fi
  }
  refute() { # refute <desc> <cmd...>  (passes if cmd exits non-zero)
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "  ✗ $desc (expected failure)"; _T_FAIL=$((_T_FAIL+1));
    else echo "  ✓ $desc"; _T_PASS=$((_T_PASS+1)); fi
  }
  finish() { echo "  -> $_T_PASS passed, $_T_FAIL failed"; [ "$_T_FAIL" -eq 0 ]; }
  mktarget() { # create a throwaway git repo, echo its path
    local d; d=$(mktemp -d); ( cd "$d" && git init -q && git config user.email t@t && git config user.name t ); echo "$d";
  }
  return 0 2>/dev/null || true
fi

# ---- runner mode ----
HW_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HW_ROOT
fail=0
for t in "$HW_ROOT"/test/test-*.sh; do
  [ -e "$t" ] || continue
  echo "== $(basename "$t") =="
  if bash "$t"; then :; else fail=1; fi
done
echo
[ "$fail" -eq 0 ] && echo "ALL TESTS PASSED" || { echo "TESTS FAILED"; exit 1; }
