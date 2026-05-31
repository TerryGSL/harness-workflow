#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
ST="$HW_ROOT/scripts/state.sh"

set_get() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$ST" set currentStage 5 >/dev/null
  local v; v=$(bash "$ST" get currentStage)
  cd - >/dev/null; rm -rf "$d"; [ "$v" = "5" ]
}
regen_from_git() {
  local d; d=$(mktarget); cd "$d" || return 2
  echo x > a; git add -A; git commit -q -m "feat: hi"
  rm -f .harness/state.json
  bash "$ST" regen >/dev/null
  local t; t=$(bash "$ST" get currentTask)
  cd - >/dev/null; rm -rf "$d"; [ "$t" = "feat: hi" ]
}
not_a_gate() {   # 删 state.json 后门禁仍照常拦 → 证明它不是 gate 输入
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$HW_ROOT/init.sh" >/dev/null 2>&1
  rm -f .harness/state.json
  mkdir -p src; echo x > src/a.ts; git add src/a.ts
  git commit -q -m "feat: x"; local rc=$?     # 缺 memory/Harness-Type → 应被 hook 拦(commit 失败)
  cd - >/dev/null; rm -rf "$d"; [ "$rc" != 0 ]
}
assert "state.sh set/get 往返" set_get
assert "state.sh regen 从 git 重建 currentTask" regen_from_git
assert "删 state.json 不影响门禁(它不是 gate 输入)" not_a_gate
finish
