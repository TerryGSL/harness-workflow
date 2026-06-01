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
start_syncs_state() {   # record.sh start 自动把任务写进 state(机械,不靠记得)
  local d; d=$(mktarget); cd "$d" || return 2
  local id; id=$(bash "$HW_ROOT/scripts/record.sh" start feature 同步测试)
  local t s; t=$(bash "$ST" get currentTask); s=$(bash "$ST" get currentStage)
  cd - >/dev/null; rm -rf "$d"; [ "$t" = "$id" ] && [ "$s" = "in_progress" ]
}
done_syncs_state() {    # record.sh done 自动把阶段推进到 done
  local d; d=$(mktarget); cd "$d" || return 2
  local id; id=$(bash "$HW_ROOT/scripts/record.sh" start bug y)
  python3 -c 'import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read().replace("<TODO>","实际");open(p,"w",encoding="utf-8").write(s)' ".harness/records/$id.md"
  bash "$HW_ROOT/scripts/record.sh" done "$id" >/dev/null 2>&1
  local s; s=$(bash "$ST" get currentStage)
  cd - >/dev/null; rm -rf "$d"; [ "$s" = "done" ]
}
done_fail_no_advance() {  # done 校验失败(段落空)→ state 绝不能被推进到 done(锁死 codex 的担心)
  local d; d=$(mktarget); cd "$d" || return 2
  local id; id=$(bash "$HW_ROOT/scripts/record.sh" start bug z)   # start → in_progress
  bash "$HW_ROOT/scripts/record.sh" done "$id" >/dev/null 2>&1    # 段落仍 <TODO> → 校验 exit 1
  local s; s=$(bash "$ST" get currentStage)
  cd - >/dev/null; rm -rf "$d"; [ "$s" = "in_progress" ]          # 没被推进到 done
}
assert "state.sh set/get 往返" set_get
assert "state.sh regen 从 git 重建 currentTask" regen_from_git
assert "删 state.json 不影响门禁(它不是 gate 输入)" not_a_gate
assert "record.sh start 自动同步 state(currentTask+in_progress)" start_syncs_state
assert "record.sh done 自动同步 state(currentStage=done)" done_syncs_state
assert "record.sh done 校验失败时 state 不推进到 done(codex 锁死)" done_fail_no_advance
finish
