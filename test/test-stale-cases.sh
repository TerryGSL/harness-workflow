#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
SC="$HW_ROOT/scripts/stale-cases.sh"

lists_old_case() {
  local d; d=$(mktarget); cd "$d" || return 2
  mkdir -p docs/memory/cases
  echo x > docs/memory/cases/old.md
  touch -t 202001010000 docs/memory/cases/old.md   # backdate ~years
  local out; out=$(bash "$SC" 2>/dev/null)
  cd - >/dev/null; rm -rf "$d"
  printf '%s' "$out" | grep -q 'old.md'
}
ignores_fresh_case() {
  local d; d=$(mktarget); cd "$d" || return 2
  mkdir -p docs/memory/cases
  echo x > docs/memory/cases/fresh.md           # mtime = now
  local out; out=$(bash "$SC" 2>/dev/null)
  cd - >/dev/null; rm -rf "$d"
  ! printf '%s' "$out" | grep -q 'fresh.md'
}

assert "stale-cases lists a >90d case" lists_old_case
assert "stale-cases ignores a fresh case" ignores_fresh_case
finish
