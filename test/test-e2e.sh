#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
INIT="$HW_ROOT/init.sh"

e2e_memory_gate_blocks() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$INIT" >/dev/null 2>&1
  mkdir -p src; echo "code" > src/a.ts; git add -A
  git commit -q -m "feat: add a" ; local rc=$?   # should be BLOCKED (no case, no trailer)
  cd - >/dev/null; rm -rf "$d"; return $rc
}
e2e_memory_gate_trailer_passes() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$INIT" >/dev/null 2>&1
  mkdir -p src; echo "code" > src/a.ts; git add -A
  git commit -q -m $'feat: add a\n\nHarness-Type: trivial\nMemory: none' ; local rc=$?   # should PASS
  cd - >/dev/null; rm -rf "$d"; return $rc
}
e2e_secrets_blocked() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$INIT" >/dev/null 2>&1
  echo "K=v" > .env; git add -A
  git commit -q -m $'chore\n\nMemory: none' ; local rc=$?   # should be BLOCKED by pre-commit
  cd - >/dev/null; rm -rf "$d"; return $rc
}

refute "e2e: code commit w/o memory is blocked" e2e_memory_gate_blocks
assert "e2e: code commit with Memory: trailer passes" e2e_memory_gate_trailer_passes
refute "e2e: committing .env is blocked" e2e_secrets_blocked
finish
