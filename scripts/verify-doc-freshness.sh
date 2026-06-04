#!/usr/bin/env bash
# verify-doc-freshness.sh — 专管"活文档"不烂(supervisor 每轮 + ci-gate 跑)。
# 查三样机械可判的:
#   1. 纸面承诺:CLAUDE.md/AGENTS.md 里指向 docs/* 的文件必须真存在(治 STATE.json/WALKTHROUGH 死链)
#   2. locale 漂移:docs/code-map.json 的 locales 必须 == src 真实 messages 目录
#   3. 生成文档存在:code-map.json / records-index.md 必须在(光有脚本不算)
# 不查"内容对不对"(那要 LLM,会烂);只查机械事实。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "doc-freshness: not a git repo" >&2; exit 1; }
cd "$ROOT"
fail=0

# 1. 死链:CLAUDE.md + AGENTS.md 里写的 docs/xxx 必须存在(纸面承诺门)
refs=$(grep -rhoE 'docs/[A-Za-z0-9._/-]+\.(md|json)' CLAUDE.md AGENTS.md 2>/dev/null | sort -u || true)
missing=""
for f in $refs; do [ -e "$f" ] || missing="$missing $f"; done
if [ -n "$missing" ]; then
  echo "✗ doc-freshness: 规则文档承诺了不存在的文件(纸面承诺):" >&2
  for f in $missing; do echo "    $f" >&2; done
  echo "  修:要么创建该文件,要么从 CLAUDE.md/AGENTS.md 删掉这条承诺。" >&2
  fail=1
fi

# 2. locale 漂移:code-map.locales 必须 == src 真实目录(自动探测常见 messages 目录)
if [ -f docs/code-map.json ] && command -v node >/dev/null 2>&1; then
  msgdir=""
  for d in src/config/locale/messages src/i18n/messages src/messages messages src/locales; do
    [ -d "$d" ] && { msgdir="$d"; break; }
  done
  actual=""
  [ -n "$msgdir" ] && actual=$(find "$msgdir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed -E 's#.*/##' | sort | paste -sd ',' -)
  mapped=$(node -e "try{const d=require('./docs/code-map.json');console.log((d.locales||[]).sort().join(','))}catch(e){console.log('ERR')}" 2>/dev/null)
  if [ "$mapped" != "ERR" ] && [ -n "$actual" ] && [ "$actual" != "$mapped" ]; then
    echo "✗ doc-freshness: locale 漂移 — 真实[$actual] vs code-map[$mapped]。重生成:node scripts/gen-code-map.mjs" >&2
    fail=1
  fi
fi

# 3. 生成文档必须存在(有脚本就得有产物)
for pair in "scripts/gen-code-map.mjs:docs/code-map.json" "scripts/distill-records.sh:docs/memory/records-index.md"; do
  s="${pair%%:*}"; o="${pair##*:}"
  if [ -f "$s" ] && [ ! -f "$o" ]; then
    echo "✗ doc-freshness: $s 存在但产物 $o 缺失。跑一次生成它。" >&2
    fail=1
  fi
done

exit "$fail"
