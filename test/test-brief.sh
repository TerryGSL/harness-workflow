#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
BR="$HW_ROOT/scripts/brief.sh"
briefs_state_and_git() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$HW_ROOT/init.sh" >/dev/null 2>&1
  echo x > a; git add -A; git commit -q --no-verify -m $'feat: 基线\n\nHarness-Type: trivial\nMemory: none'
  bash "$HW_ROOT/scripts/state.sh" set currentTask "做登录" >/dev/null
  local out; out=$(bash "$BR" "实现登录表单" "src/auth/**")
  cd - >/dev/null; rm -rf "$d"
  printf '%s' "$out" | grep -q "实现登录表单" \
    && printf '%s' "$out" | grep -q "做登录" \
    && printf '%s' "$out" | grep -qE "基线|git log" \
    && printf '%s' "$out" | grep -q "src/auth"
}
assert "brief 产出含任务+文件边界+当前state+近期git的自包含简报" briefs_state_and_git
finish
