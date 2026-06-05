#!/usr/bin/env bash
# relocate-mem-injection.sh — 把全局 claude-mem 插件每轮注入进 AGENTS.md/CLAUDE.md 的
# <claude-mem-context>…</claude-mem-context> 块,从【工作树】挪到 gitignored 的
# .harness/runtime/claude-mem-context.md。SessionStart hook 跑它 → 事实源工作树也保持干净
# (commit 边界另有 strip-mem-injection 兜底)。memory 上下文不丢,只换地方,agent 仍可读。
#
# 安全第一(本脚本自动改事实源文件,codex 审加固):
#  - 仓库根优先用 $CLAUDE_PROJECT_DIR(hook cwd 可能不在本仓),回退 git rev-parse。
#  - 只在块「良构」(首 open 行 < 首 close 行 且 open==close≥1)才动;否则原样保留(防 close-before-open 删到 EOF)。
#  - 先把块安全存进 runtime,再剥;剥离结果必须 非空 + 已去净 tag + 管道成功 才 mv 覆盖,否则保留原文件。
#  - 多文件各自 append 到 runtime(不互相覆盖);任一步失败即跳过该文件,绝不用半成品覆盖真文件。
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-}"
{ [ -n "$ROOT" ] && [ -d "$ROOT" ]; } || ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0
OPEN='<claude-mem-context>'
CLOSE='</claude-mem-context>'
RUNTIME=".harness/runtime/claude-mem-context.md"
mkdir -p .harness/runtime || exit 0
acc=$(mktemp) || exit 0
wrote_any=0

for f in "$@"; do
  [ -f "$f" ] || continue
  grep -qF -- "$OPEN" "$f" || continue
  nopen=$(grep -cF -- "$OPEN" "$f" || true)
  nclose=$(grep -cF -- "$CLOSE" "$f" || true)
  lopen=$(grep -nF -- "$OPEN" "$f" | head -1 | cut -d: -f1)
  lclose=$(grep -nF -- "$CLOSE" "$f" | head -1 | cut -d: -f1)
  if [ "$nopen" != "$nclose" ] || [ "${nopen:-0}" -lt 1 ] || [ -z "$lopen" ] || [ -z "$lclose" ] || [ "$lopen" -ge "$lclose" ]; then
    echo "⚠ relocate-mem:$f 注入块不良构(open=$nopen close=$nclose 首open行$lopen 首close行$lclose),保留不动。" >&2
    continue
  fi
  block=$(awk -v o="$OPEN" -v c="$CLOSE" 'index($0,o){p=1} p{print} index($0,c){p=0}' "$f")
  [ -n "$block" ] || { echo "⚠ relocate-mem:$f 抽块为空,跳过。" >&2; continue; }
  # 先安全存块(append,不覆盖其它文件的块)
  { echo "<!-- from $f -->"; printf '%s\n' "$block"; echo; } >> "$acc" || { echo "⚠ relocate-mem:写 runtime 失败,$f 保留不动。" >&2; continue; }
  # 再剥;结果必须非空 + 去净 tag + 管道成功,否则不覆盖
  tmp=$(mktemp) || continue
  if sed "\%$OPEN%,\%$CLOSE%d" "$f" | awk 'NF{last=NR} {buf[NR]=$0} END{for(i=1;i<=last;i++) print buf[i]}' > "$tmp" \
     && [ -s "$tmp" ] && ! grep -qF -- "$OPEN" "$tmp" && ! grep -qF -- "$CLOSE" "$tmp"; then
    mv "$tmp" "$f"; wrote_any=1
    echo "✓ relocate-mem:$f 的 claude-mem 块已挪走(工作树已清)" >&2
  else
    rm -f "$tmp"
    echo "⚠ relocate-mem:$f 剥离结果异常(空/残留 tag/管道失败),保留原文件不动。" >&2
  fi
done

# 只有真挪了块才落 runtime 正本(失败不留半文件)
if [ "$wrote_any" = 1 ] && [ -s "$acc" ]; then mv "$acc" "$RUNTIME"; else rm -f "$acc"; fi
exit 0
