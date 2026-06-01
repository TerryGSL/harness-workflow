#!/usr/bin/env bash
# verify-evidence.sh <commit-msg-file> — 证据门(commit-msg 路径)。
# 改了代码必须声明 Harness-Type, 并按类型带证据 artifact。规则与 ci-gate 共享 gate-lib。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/gate-lib.sh"
MSG="${1:-}"; [ -f "$MSG" ] || { echo "verify-evidence: 缺 commit message 文件" >&2; exit 2; }

# 回退类豁免
head -1 "$MSG" | grep -qE "$MEMORY_EXEMPT_RE" && exit 0
grep -qiE '^(Revert|Rollback):' "$MSG" && exit 0
# merge commit 豁免:合并的是各自已过门的提交,merge commit 本身不重复证据门(否则并行/分支合并会卡)
{ [ -f "$(git rev-parse --git-dir 2>/dev/null)/MERGE_HEAD" ] || head -1 "$MSG" | grep -qiE '^merge[ (]'; } && exit 0

staged=$(git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
significant=$(printf '%s\n' "$staged" | grep -E "$SIGNIFICANT_RE" || true)
[ -z "$significant" ] && exit 0   # 非代码改动不要求证据

type=$(grep -iE "$HARNESS_TYPE_RE" "$MSG" | grep -oiE '(trivial|bug|feature|refactor)' | head -1 | tr 'A-Z' 'a-z')
if [ -z "$type" ]; then
  echo "✗ 证据门：改了代码必须声明任务类型 → commit 信息加 Harness-Type: trivial|bug|feature|refactor" >&2
  exit 1
fi
# 沉淀门(非 trivial 通用):必须带 Harness-Record:<id> 且同 commit 改了对应 record.md
if [ "$type" != "trivial" ]; then
  rid=$(grep -iE "$HARNESS_RECORD_RE" "$MSG" | head -1 | sed -E 's/^[Hh]arness-[Rr]ecord:[[:space:]]*//' | tr -d '[:space:]')
  if [ -z "$rid" ]; then
    echo "✗ 沉淀门：$type commit 必须带 trailer  Harness-Record: <id>（先 record.sh start 拿 id）" >&2; exit 1
  fi
  if ! printf '%s\n' "$staged" | grep -qxF ".harness/records/$rid.md"; then
    echo "✗ 沉淀门：必须在同一 commit 里改 .harness/records/$rid.md（沉淀绑定本次变更）" >&2; exit 1
  fi
fi

case "$type" in
  trivial) ;;
  bug)
    printf '%s\n' "$staged" | grep -qE "$TEST_FILE_RE" && exit 0
    grep -qiE '^No-Repro:[[:space:]]*[^[:space:]]' "$MSG" && exit 0
    echo "✗ 证据门(bug)：需同 commit 含测试文件，或加 No-Repro: <为何无法自动复现>" >&2; exit 1 ;;
  feature)
    plan=$(grep -iE '^Plan:[[:space:]]*\S' "$MSG" | head -1 | sed -E 's/^[Pp]lan:[[:space:]]*//')
    ok=0
    [ -n "$plan" ] && [ -e "$plan" ] && ok=1
    printf '%s\n' "$staged" | grep -qiE '^docs/.*plan.*\.md$' && ok=1
    [ "$ok" = 1 ] || { echo "✗ 证据门(feature)：需 Plan: <存在的计划文件> 或同 commit 含 docs/**plan*.md" >&2; exit 1; }
    grep -qiE '^Reviewed-by:[[:space:]]*[^[:space:]]' "$MSG" || { echo "✗ 证据门(feature)：需 Reviewed-by: <codex|...>(过一道独立审查并留痕)" >&2; exit 1; }
    grep -qiE "$BRAINSTORMED_RE" "$MSG" || { echo "✗ 证据门(feature)：需 Brainstormed-by: <superpowers:brainstorming | none:理由>(脑暴先行留痕)" >&2; exit 1; } ;;
  refactor)
    grep -qiE '^Behavior-Unchanged:[[:space:]]*(true|yes|是)' "$MSG" || { echo "✗ 证据门(refactor)：需 Behavior-Unchanged: true(测试绿由 pre-push/CI 验)" >&2; exit 1; } ;;
esac
exit 0
