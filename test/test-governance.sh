#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
VG="$HW_ROOT/scripts/verify-governance.sh"

passes_within_limits() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$HW_ROOT/init.sh" >/dev/null 2>&1
  bash "$VG" >/dev/null 2>&1; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc   # 模板默认在限内 → 0
}
blocks_oversized_agents() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$HW_ROOT/init.sh" >/dev/null 2>&1
  for i in $(seq 1 70); do echo "- 填充行 $i" >> AGENTS.md; done   # 撑过 60 行
  bash "$VG" >/dev/null 2>&1; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc    # 应 != 0
}
blocks_oversized_workflow() {
  local d; d=$(mktarget); cd "$d" || return 2
  bash "$HW_ROOT/init.sh" >/dev/null 2>&1
  for i in $(seq 1 160); do echo "填充 $i" >> docs/WORKFLOW.md; done
  bash "$VG" >/dev/null 2>&1; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc    # 应 != 0
}

assert "verify-governance 在限内通过" passes_within_limits
refute "verify-governance 拦超长 AGENTS.md" blocks_oversized_agents
refute "verify-governance 拦超长 WORKFLOW.md" blocks_oversized_workflow
finish
