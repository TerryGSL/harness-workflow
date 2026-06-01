#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
R="$HW_ROOT/scripts/record.sh"

start_creates_record() {
  local d; d=$(mktarget); cd "$d" || return 2
  local id; id=$(bash "$R" start feature 登录)
  local f=".harness/records/$id.md"
  local ok=0
  [ -f "$f" ] || ok=1
  grep -q '## What' "$f" || ok=1
  grep -q '## Changed & Why' "$f" || ok=1
  grep -q '## Tests' "$f" || ok=1
  grep -q '## Tasks' "$f" || ok=1
  grep -q '## Context' "$f" || ok=1
  cd - >/dev/null; rm -rf "$d"; return $ok
}
tasks_view_shows_progress() {
  local d; d=$(mktarget); cd "$d" || return 2
  local id; id=$(bash "$R" start feature z)
  local out; out=$(bash "$R" tasks "$id")
  cd - >/dev/null; rm -rf "$d"
  printf '%s' "$out" | grep -q '0/2 done'   # 模板默认 2 条未勾
}
done_rejects_empty() {
  local d; d=$(mktarget); cd "$d" || return 2
  local id; id=$(bash "$R" start bug x)
  bash "$R" done "$id"; local rc=$?   # 段落还是 <TODO> → 应拒(非0)
  cd - >/dev/null; rm -rf "$d"; return $rc
}
done_passes_filled_and_appends_index() {
  local d; d=$(mktarget); cd "$d" || return 2
  local id; id=$(bash "$R" start bug y)
  local f=".harness/records/$id.md"
  # 填段落:把所有 <TODO> 换成实际内容
  python3 -c 'import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read().replace("<TODO>","实际内容");open(p,"w",encoding="utf-8").write(s)' "$f"
  bash "$R" done "$id"; local rc=$?
  local idx_ok=1; [ -f .harness/change-index.jsonl ] && grep -q "$id" .harness/change-index.jsonl && idx_ok=0
  cd - >/dev/null; rm -rf "$d"
  [ "$rc" = 0 ] && [ "$idx_ok" = 0 ]
}
assert "record.sh start 建 record.md(含段落+Tasks+Context)" start_creates_record
assert "record.sh tasks 显示进度 X/N" tasks_view_shows_progress
refute "record.sh done 拒空/模板段落" done_rejects_empty
assert "record.sh done 填了→过且 append change-index.jsonl" done_passes_filled_and_appends_index
finish
