#!/usr/bin/env bash
# verify-governance.sh — 单一规则源：入口文件行数上限治理。
# pre-commit 与 CI(ci-gate) 都调本脚本,避免两边规则漂移。只检查存在的文件。
# 入口文件是索引不是正文(harness-books book1 ch05);超限是老 16k 行系统的死因之一。
set -uo pipefail
fail=0
check_max() { # <file> <max>
  [ -f "$1" ] || return 0
  local n; n=$(wc -l < "$1" | tr -d ' ')
  if [ "$n" -gt "$2" ]; then
    echo "✗ governance：$1 有 $n 行,超过上限 $2 行(入口是索引不是正文,拆到 docs/ 下的 topic 文件)" >&2
    fail=1
  fi
}
check_max AGENTS.md 60
check_max docs/PROJECT.md 100
check_max docs/WORKFLOW.md 150
[ "$fail" -eq 0 ] && echo "governance：通过"
exit "$fail"
