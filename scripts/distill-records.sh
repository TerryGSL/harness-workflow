#!/usr/bin/env bash
# distill-records.sh — 蒸馏两份 generated 记忆索引(机械生成,勿手改):
#   docs/memory/records-index.md  ← .harness/records/*.md(每任务沉淀,正源)
#   docs/memory/summary.md        ← docs/memory/{cases,decisions}/*.md(跨需求稳定经验)
# 记忆合一:正源是 records + cases/decisions,这两页只是可检索索引。
# supervisor 每轮跑 + pre-commit 在 records/cases/decisions 变更时自动重蒸馏 + ci-gate 保产物在。
# 文件遍历用 find+while-read(非 for $(ls),容空格文件名;codex P2)。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "distill-records: not a git repo" >&2; exit 1; }
cd "$ROOT"
mkdir -p docs/memory

# ── records-index.md ──
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
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    id=$(basename "$f" .md)
    type=$(grep -m1 '^Type:' "$f" 2>/dev/null | sed 's/^Type:[[:space:]]*//' | tr -d '\r')
    what=$(awk '/^## What/{flag=1;next} /^## /{flag=0} flag && NF{gsub(/\r/,"");print;exit}' "$f")
    printf -- "- **%s** \`%s\` — %s\n" "$id" "${type:-?}" "${what:-（无 What 段）}"
    n=$((n+1))
  done < <(find .harness/records -maxdepth 1 -name '*.md' ! -name '._*' 2>/dev/null | sort -r)
  echo
  echo "_共 $n 条 record。_"
} > "$tmp"
mv "$tmp" "$out"

# ── summary.md ── 从 cases/decisions 蒸馏「跨需求先读」索引(治原 human 空占位永不更新)。
sout="docs/memory/summary.md"
# 迁移保护:若已存在的 summary.md 不是 generated(老 human 版有内容),先备份再覆盖(codex P2)。
if [ -f "$sout" ] && ! head -1 "$sout" 2>/dev/null | grep -qiE 'doc-status:[[:space:]]*generated'; then
  cp "$sout" "$sout.human.bak" 2>/dev/null && echo "distill-records: 旧 human summary.md 已备份 → $sout.human.bak" >&2
fi
stmp=$(mktemp)
list_dir() {  # $1=目录 $2=空时文案
  local d="$1" empty="$2" n=0 f title
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    title=$(grep -m1 '^#\{1,3\} ' "$f" 2>/dev/null | sed -E 's/^#+[[:space:]]*//' | tr -d '\r')
    printf -- "- **%s** — %s\n" "$(basename "$f" .md)" "${title:-（无标题）}"
    n=$((n+1))
  done < <(find "$d" -maxdepth 1 -name '*.md' ! -name '._*' 2>/dev/null | sort -r)
  [ "$n" = 0 ] && echo "- $empty"
}
{
  echo "<!-- doc-status: generated · owner: distill-records.sh · 触发: cases/decisions 变更自动蒸馏·勿手改 -->"
  echo "# 项目稳定经验摘要（机械生成自 docs/memory/{cases,decisions}，勿手改）"
  echo
  echo "> 跨需求高复用的稳定结论索引——新需求开工前先读这页,命中再翻对应 case/decision 全文。"
  echo "> 正源 = \`docs/memory/{cases,decisions}/*.md\`(踩坑·架构取舍,人写)。重生成:\`bash scripts/distill-records.sh\`。"
  echo
  echo "## 决策类（架构/取舍稳定结论 · docs/memory/decisions/）"
  list_dir docs/memory/decisions "（暂无；写进 docs/memory/decisions/ 即自动入此索引）"
  echo
  echo "## 案例类（实现/踩坑稳定结论 · docs/memory/cases/）"
  list_dir docs/memory/cases "（暂无；写进 docs/memory/cases/ 即自动入此索引）"
  echo
  echo "## 决策蒸馏（各任务 record 的非显然取舍 · 新→旧 · 自动抽自 .harness/records）"
  echo "> 不用单独写 cases/decisions——把取舍写进 record 的 \`## Decisions\` 段(record.sh done 强制非空),自动汇到这里。"
  dn=0; shown=0; CAP=40
  while IFS= read -r rf; do
    [ -f "$rf" ] || continue
    # Decisions 段:留非空、非占位行(保留多行续行,不只 '- ' 行·codex P2)
    decs=$(awk '/^## Decisions/{flag=1;next} /^## /{flag=0} flag' "$rf" \
      | grep -vE '^[[:space:]]*$' \
      | grep -viE '^[[:space:]]*-?[[:space:]]*(<TODO>|无|none|n/a)[[:space:]]*$')
    [ -n "$decs" ] || continue
    dn=$((dn+1))
    if [ "$shown" -lt "$CAP" ]; then
      echo "- \`$(basename "$rf" .md)\`"                    # id 作 code span,防 slug 里的 markdown 注入
      printf '%s\n' "$decs" | head -12 | sed 's/^/  /'      # 整段缩进 2 格(保留 bullet/续行),每 record 封顶 12 行
      shown=$((shown+1))
    fi
  done < <(find .harness/records -maxdepth 1 -name '*.md' ! -name '._*' 2>/dev/null | sort -r)
  [ "$dn" = 0 ] && echo "- （暂无；record 的 \`## Decisions\` 写了取舍就自动入此）"
  [ "$dn" -gt "$CAP" ] && { echo; echo "_仅显最近 $CAP/$dn 条有取舍的 record;更早翻 .harness/records/。_"; }
} > "$stmp"
mv "$stmp" "$sout"

echo "distill-records: records-index($(grep -c '^- ' "$out") 条) + summary(cases/decisions + 决策蒸馏) 已重生成" >&2
