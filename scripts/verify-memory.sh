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

# 修复类提交(fix:/fix( )必须留下坑的解法 —— 修了 bug/坑却 Memory: none,坑就流失了。
# 没记 case 文件(上面已 exit)且首行是 fix 且 Memory 是 none/trivial → 拒。要么记 case,要么写实质一句话。
if head -1 "$MSG_FILE" | grep -qiE '^fix[ (:]' && grep -qiE '^Memory:[[:space:]]*(none|trivial|无)[[:space:]]*$' "$MSG_FILE"; then
  cat >&2 <<'EOF'
✗ memory 门禁(fix 类提交)：修了 bug/坑,不接受 Memory: none——坑会流失,以后还踩。二选一：
    • 加 docs/memory/cases/<日期>-<slug>.md   （记根因+解法,以后不再踩;最推荐）
    • 或写实质 trailer：Memory: <一句话根因+解法>   （不能是 none/trivial）
EOF
  exit 1
fi

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
