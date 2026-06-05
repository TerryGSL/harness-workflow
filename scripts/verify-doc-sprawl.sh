#!/usr/bin/env bash
# verify-doc-sprawl.sh — 防文档泛滥复发。根层 *.md 只允许白名单内的(治"又冒出一堆
# handoff/plan/变体文档堆在根目录")。白名单外的根文档 → 移到 docs/ 或 docs/archive/。
# 白名单 = 默认(AGENTS/CLAUDE/README)+ 可选 .harness/doc-sprawl-allow(每行一个文件名)。
#   pre-commit(--fix): 只警告,不挡循环。   CI(check): 违例 → exit 1。
# 另对超大 docs(>300KB)出归档提醒(不硬卡——大小不是危险,硬卡会变剧场)。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "verify-doc-sprawl: not a git repo" >&2; exit 1; }
cd "$ROOT"
mode="${1:-check}"
fail=0

# 默认白名单(通用治理/入口文档)+ 项目扩展(.harness/doc-sprawl-allow,每行一个文件名)
WHITELIST="AGENTS.md CLAUDE.md README.md"
if [ -f .harness/doc-sprawl-allow ]; then
  extra=$(grep -vE '^[[:space:]]*(#|$)' .harness/doc-sprawl-allow 2>/dev/null | tr '\n' ' ')
  WHITELIST="$WHITELIST $extra"
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  case " $WHITELIST " in
    *" $f "*) ;;
    *)
      echo "✗ doc-sprawl: 根层多了非白名单文档 $f。移到 docs/(或完成的交接移 docs/archive/)。" >&2
      echo "  确属根层入口就把文件名加进 .harness/doc-sprawl-allow(每行一个·不支持含空格名,想清楚再加)。" >&2
      [ "$mode" = "check" ] && fail=1
      ;;
  esac
done < <(find . -maxdepth 1 -name '*.md' -not -name '._*' 2>/dev/null | sed 's#^\./##' | sort)

# 超大活文档警告(只提醒归档,不 fail)。
LIMIT=$((300*1024))
if [ -d docs ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    sz=$(wc -c < "$f" 2>/dev/null || echo 0)
    [ "$sz" -gt "$LIMIT" ] && echo "⚠ doc-sprawl: $f 已 $((sz/1024))KB(>300KB)——考虑把历史抽到 docs/archive/。" >&2
  done < <(find docs -maxdepth 1 -name '*.md' -not -name '._*' 2>/dev/null)
fi

exit "$fail"
