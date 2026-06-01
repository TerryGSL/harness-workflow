#!/usr/bin/env bash
# verify-memory.sh <commit-msg-file>
# Memory gate (client-side, commit-msg hook). If staged changes touch significant
# paths, require either a staged docs/memory/{cases,decisions} file OR a visible
# `Memory:` trailer. Shares patterns with ci-gate.sh via gate-lib.sh.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/gate-lib.sh"

MSG_FILE="${1:-}"
if [ -z "$MSG_FILE" ] || [ ! -f "$MSG_FILE" ]; then
  echo "verify-memory: missing commit message file" >&2; exit 2
fi

staged=$(git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
[ -z "$staged" ] && exit 0

# 回退/rollback/merge 类提交豁免 —— 紧急回滚 + merge commit(合并的是已过门提交)不该被 memory 门卡。
if head -1 "$MSG_FILE" | grep -qE "$MEMORY_EXEMPT_RE" || grep -qiE '^(Revert|Rollback):' "$MSG_FILE" \
   || [ -f "$(git rev-parse --git-dir 2>/dev/null)/MERGE_HEAD" ] || head -1 "$MSG_FILE" | grep -qiE '^merge[ (]'; then
  exit 0
fi

significant=$(printf '%s\n' "$staged" | grep -E "$SIGNIFICANT_RE" || true)
[ -z "$significant" ] && exit 0

mem_staged=$(printf '%s\n' "$staged" | grep -E "$MEMORY_FILE_RE" || true)
[ -n "$mem_staged" ] && exit 0

if grep -qiE "$MEMORY_TRAILER_RE" "$MSG_FILE"; then
  exit 0
fi

cat >&2 <<'EOF'
✗ memory 门禁：本次提交动了代码/schema/测试，但没记录任何 memory。
  三选一：
    • 加 docs/memory/cases/<日期>-<slug>.md      （修了 bug / 非平凡的坑）
    • 加 docs/memory/decisions/<日期>-<slug>.md  （非显然的架构取舍）
    • commit 信息里加一行 trailer：               Memory: none   （或：trivial）
  trailer 会记进 git 历史——偷懒留痕。
EOF
exit 1
