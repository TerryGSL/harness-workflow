#!/usr/bin/env bash
# distill-records.sh — 把 .harness/records/*.md(每任务沉淀正源)蒸馏成
# docs/memory/records-index.md(可检索索引)。记忆合一:records=正源,docs/memory=产物。
# 机械生成,勿手改。supervisor 每 N 轮跑 + ci-gate 保证产物存在。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "distill-records: not a git repo" >&2; exit 1; }
cd "$ROOT"

mkdir -p docs/memory
out="docs/memory/records-index.md"
tmp=$(mktemp)

{
  echo "<!-- doc-status: generated · owner: distill-records.sh · 触发: .harness/records 变更自动蒸馏·勿手改 -->"
  echo "# Records 索引（机械生成自 .harness/records，勿手改）"
  echo
  echo "> 正源 = \`.harness/records/<id>.md\`(每任务沉淀)。本页 = 可检索索引。"
  echo "> 重生成:\`bash scripts/distill-records.sh\`。跨任务教训/架构取舍另入 docs/memory/{cases,decisions}/。"
  echo
  n=0
  # 按文件名倒序(新→旧)
  for f in $(ls -1 .harness/records/*.md 2>/dev/null | grep -v '/\._' | sort -r); do
    [ -f "$f" ] || continue
    id=$(basename "$f" .md)
    type=$(grep -m1 '^Type:' "$f" 2>/dev/null | sed 's/^Type:[[:space:]]*//' | tr -d '\r')
    # What 段第一行非空正文
    what=$(awk '/^## What/{flag=1;next} /^## /{flag=0} flag && NF{gsub(/\r/,"");print;exit}' "$f")
    printf -- "- **%s** \`%s\` — %s\n" "$id" "${type:-?}" "${what:-（无 What 段）}"
    n=$((n+1))
  done
  echo
  echo "_共 $n 条 record。_"
} > "$tmp"

mv "$tmp" "$out"
echo "distill-records: 索引 $out 已重生成($(grep -c '^- ' "$out") 条)" >&2
