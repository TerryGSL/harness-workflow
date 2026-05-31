#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
DOC="$HW_ROOT/scripts/doctor.sh"

healthy_after_init() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$HW_ROOT/init.sh" >/dev/null 2>&1
  bash "$DOC" >/dev/null 2>&1; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc   # init 过 → 0
}
fails_on_empty_repo() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$DOC" >/dev/null 2>&1; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc   # 空 repo → 非 0
}

assert "doctor 在 init 过的 repo 通过" healthy_after_init
refute "doctor 在空 repo 报缺项" fails_on_empty_repo
finish
