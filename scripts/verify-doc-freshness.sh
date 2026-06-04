#!/usr/bin/env bash
# verify-doc-freshness.sh — 专管"活文档"不烂(supervisor 每轮 + ci-gate 跑)。
# 查四样机械可判的:
#   1. 纸面承诺:CLAUDE.md/AGENTS.md 里指向 docs/* 的文件必须真存在(治死链)
#   2. locale 漂移:docs/code-map.json 的 locales 必须 == src 真实 messages 目录
#   3. 生成文档存在:code-map.json / records-index.md 必须在(光有脚本不算)
#   4. doc-status 自描述:每个管理文档首部必须声明 <!-- doc-status: X -->(治死文件——
#      没声明=不知道谁维护=迟早烂;声明了「冻结」和「烂掉」才区分得开)。
# 不查"内容对不对"(那要 LLM,会烂);只查机械事实。
# DOC_STATUS 合法值:generated|living|rules|curated|frozen|archived(见 docs/WORKFLOW.md)。
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

# 3. 生成文档必须存在,**但只在对应「源」存在时要求**(否则无 src/ 的脚本/文档仓被永久卡死·codex P1)。
#    code-map ← src/ 存在才要;records-index ← .harness/records/ 有记录才要。
if [ -f scripts/gen-code-map.mjs ] && [ -d src ] && [ ! -f docs/code-map.json ]; then
  echo "✗ doc-freshness: 有 src/ 和 gen-code-map.mjs 但缺 docs/code-map.json。跑:node scripts/gen-code-map.mjs" >&2
  fail=1
fi
if [ -f scripts/distill-records.sh ] && ls .harness/records/*.md >/dev/null 2>&1 && [ ! -f docs/memory/records-index.md ]; then
  echo "✗ doc-freshness: 有 .harness/records 但缺 docs/memory/records-index.md。跑:bash scripts/distill-records.sh" >&2
  fail=1
fi

# 4. doc-status 自描述门:每个「管理文档」**首行**必须是 <!-- doc-status: X -->(锚定首行,防正文骗过·codex P2)。
#    管理范围 = 根层 *.md(不递归)+ docs/ 下递归。豁免:README / docs/{archive,specs,memory}。
DOC_STATUS_RE='^[[:space:]]*<!--[[:space:]]*doc-status:[[:space:]]*(generated|living|rules|curated|frozen|archived)\b'
undeclared=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  f="${f#./}"
  # README 不再豁免(用户提:豁免=必死)。doc-status 是 HTML 注释,GitHub 渲染不可见,无害。
  case "$f" in
    docs/archive/*|docs/specs/*|docs/memory/*) continue ;;
  esac
  if ! head -1 "$f" 2>/dev/null | grep -qiE "$DOC_STATUS_RE"; then
    undeclared="$undeclared $f"
  fi
done < <( { find . -maxdepth 1 -name '*.md' -not -name '._*'; [ -d docs ] && find docs -name '*.md' -not -name '._*'; } 2>/dev/null | sort -u )
if [ -n "$undeclared" ]; then
  echo "✗ doc-freshness: 以下文档首行没声明 doc-status(不知道谁维护→迟早成死文件):" >&2
  for f in $undeclared; do echo "    $f" >&2; done
  echo "  修:**首行**加 <!-- doc-status: generated|living|rules|curated|frozen|archived -->(见 docs/WORKFLOW.md)。" >&2
  fail=1
fi

exit "$fail"
