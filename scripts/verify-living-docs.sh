#!/usr/bin/env bash
# verify-living-docs.sh — 治"活文档悄悄烂"。WORKFLOW 里标 `doc-status: living` 的文档号称
# "循环刷",但没有任何门检测它是否真在刷,于是停在几天前。本门让 living 变成可机械验的合同:
#
#   合同① 每个 `doc-status: living` 文档必须在 .harness/living-docs.json 有条目(声明 triggers+SLA),
#         否则 fail:要么声明它靠什么触发刷新,要么把它降级成 frozen/curated/rules(别挂羊头)。
#   合同② 注册的文档不得"落后触发源太多提交":数它上次更新后、有多少提交动了它的 triggers。
#         落后 ≥ warnCommits → 警告;≥ failCommits → CI fail。文档刷新一次→落后归零。
#
# 用"落后提交数"而非墙钟天数:不因时间流逝误伤无关提交,只在 triggers 真变了而文档没跟时报警。
#   pre-commit(--fix): 只警告,不挡循环。   CI(check): 合同①违例或 ≥failCommits → exit 1。
# 注:兼容 macOS bash 3.2(不用 mapfile / 关联数组)。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "verify-living-docs: not a git repo" >&2; exit 1; }
cd "$ROOT"
mode="${1:-check}"
# 无 node 无法解析 JSON 注册表 → 降级跳过(否则把所有 living 文档误判成未注册·codex P2)。
command -v node >/dev/null 2>&1 || { echo "⚠ verify-living-docs: node 缺,跳过(无法解析注册表)" >&2; exit 0; }
reg=".harness/living-docs.json"
fail=0

# 所有 doc-status: living 文档(根层 *.md 不递归 + docs/ 递归,排除 archive)
living=$( { find . -maxdepth 1 -name '*.md' -not -name '._*'; [ -d docs ] && find docs -name '*.md' -not -name '._*'; } 2>/dev/null \
  | sed 's#^\./##' | sort -u | while IFS= read -r f; do
      [[ "$f" == docs/archive/* ]] && continue
      head -1 "$f" 2>/dev/null | grep -qiE 'doc-status:[[:space:]]*living' && echo "$f"
    done )

# 注册表 → 行 "doc|trig1 trig2|warn|fail"(node 解析 JSON)
reglines=""
if [ -f "$reg" ] && command -v node >/dev/null 2>&1; then
  reglines=$(node -e '
    const r=require("./'"$reg"'");
    for(const e of (r.docs||[])) console.log([e.doc,(e.triggers||[]).join(" "),e.warnCommits==null?15:e.warnCommits,e.failCommits==null?50:e.failCommits].join("|"));
  ' 2>/dev/null || true)
fi
registered=$(printf '%s\n' "$reglines" | awk -F'|' 'NF{print $1}')

# 合同①:living 必须注册
for f in $living; do
  [ -z "$f" ] && continue
  if ! printf '%s\n' "$registered" | grep -qxF "$f"; then
    echo "✗ living-docs: $f 标了 doc-status: living 但 .harness/living-docs.json 无条目。" >&2
    echo "  修:给它声明 {doc,triggers,warnCommits,failCommits},或把 doc-status 改成 frozen/curated/rules。" >&2
    fail=1
  fi
done

# 合同②:落后提交数(while 用 here-string,留在当前 shell 以便 fail 生效)
while IFS='|' read -r d trig w fa; do
  [ -z "${d:-}" ] && continue
  if [ ! -f "$d" ]; then echo "⚠ living-docs: 注册了不存在的文档 $d(清理 $reg)" >&2; continue; fi
  # 注册了但已不是 living(降级 frozen/curated/rules)→ 注册表陈旧,清晰报错而非日后在触发提交上莫名 fail(codex P2)。
  if ! printf '%s\n' "$living" | grep -qxF "$d"; then
    echo "✗ living-docs: $d 在 $reg 注册,但已不是 doc-status: living(降级了就从注册表删该条目)。" >&2
    [ "$mode" = "check" ] && fail=1
    continue
  fi
  docLast=$(git log -1 --format=%H -- "$d" 2>/dev/null || true)
  [ -z "$docLast" ] && continue   # 还没提交 = 新文档,不算落后
  # shellcheck disable=SC2086
  behind=$(git rev-list --count "${docLast}..HEAD" -- $trig 2>/dev/null || echo 0)
  if [ "$behind" -ge "$fa" ]; then
    echo "✗ living-docs: $d 落后触发源 $behind 次提交(≥ fail 阈值 $fa)。刷新它或改 doc-status。" >&2
    [ "$mode" = "check" ] && fail=1
  elif [ "$behind" -ge "$w" ]; then
    echo "⚠ living-docs: $d 落后触发源 $behind 次提交(≥ warn 阈值 $w,fail 在 $fa)——该刷了。" >&2
  fi
done <<EOF
$reglines
EOF

exit "$fail"
