#!/usr/bin/env bash
# strip-mem-injection.sh — 提交前从入口文件的【暂存区 blob】剥离 claude-mem 机器注入块。
# 背景：SessionStart 的 claude-mem hook 每轮把记忆上下文写进 AGENTS.md(<claude-mem-context>…
# </claude-mem-context>),`git add -A` 又把它扫进提交,周期性顶破 AGENTS.md≤60 行治理门。
# 多轮手动 revert 不生效(下轮重注入)。本脚本在 pre-commit 直接改 index(不动工作树),
# 让 committed 版本恒为干净正文 —— 根治。
# 设计要点(对抗 Codex 审):
#  - 只读/改【暂存 blob】(git show :f / update-index),不碰工作树 → 不破坏 partial commit,
#    且关闭"index 含注入但工作树已干净"导致漏判的 fail-open。
#  - 标签必须成对(open==close 且 ≥1)才剥;不配对则 fail-closed(退出 1,逼人工处理),
#    绝不让悬空 open 把范围删到 EOF 而误伤正文。
#  - set -euo pipefail + 显式校验;任何环节失败即中止提交,不静默放过注入块。
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
OPEN='<claude-mem-context>'
CLOSE='</claude-mem-context>'
staged=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
is_staged() { printf '%s\n' "$staged" | grep -qxF -- "$1"; }

for f in "$@"; do
  is_staged "$f" || continue
  blob=$(git show ":$f" 2>/dev/null) || continue   # 读暂存 blob,不存在则跳
  printf '%s\n' "$blob" | grep -qF -- "$OPEN" || continue   # index 无注入 → 空操作

  nopen=$(printf '%s\n' "$blob" | grep -cF -- "$OPEN" || true)
  nclose=$(printf '%s\n' "$blob" | grep -cF -- "$CLOSE" || true)
  if [ "$nopen" != "$nclose" ] || [ "$nopen" -lt 1 ]; then
    echo "✗ strip-mem：$f 暂存区注入块标签不配对(open=$nopen close=$nclose),拒绝自动剥离。" >&2
    echo "  请手动清理后再提交(防止悬空标签误删正文)。" >&2
    exit 1
  fi

  # 删注入块(\%…% 地址形式避免转义 close tag 的 /)+ 去末尾遗留空行,留单尾换行
  cleaned=$(printf '%s\n' "$blob" \
    | sed "\%$OPEN%,\%$CLOSE%d" \
    | awk 'NF{last=NR} {buf[NR]=$0} END{for(i=1;i<=last;i++) print buf[i]}')
  newsha=$(printf '%s\n' "$cleaned" | git hash-object -w --stdin)
  mode=$(git ls-files --stage -- "$f" | awk 'NR==1{print $1}')
  [ -n "$mode" ] && [ -n "$newsha" ] || { echo "✗ strip-mem：$f 取 mode/sha 失败" >&2; exit 1; }
  git update-index --cacheinfo "$mode,$newsha,$f"
  echo "✓ strip-mem：已从暂存区 $f 剥离 claude-mem 注入块(index-only,工作树不动)" >&2
done
exit 0
