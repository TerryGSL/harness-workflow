#!/usr/bin/env bash
# install.sh — 把指挥家 skill 装进 ~/.claude/skills 让 Claude 能调用。
# 只负责"可用",不是强制层(强制靠 repo 内 git hooks + CI)。
# 用法:
#   bash install.sh              # 默认装成 harness-workflow;若该名已被别处占用则报错不覆盖
#   bash install.sh --name X     # 装成自定义名(避免与旧的撞)
#   bash install.sh --force      # 旧的 harness-workflow 若是软链则备份为 harness-workflow.legacy 再接管
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SRC/skill/harness-workflow"
DEST_DIR="$HOME/.claude/skills"
NAME="harness-workflow"; FORCE=0
while [ "$#" -gt 0 ]; do case "$1" in
  --name) NAME="$2"; shift 2 ;;
  --force) FORCE=1; shift ;;
  *) echo "未知参数: $1" >&2; exit 2 ;;
esac; done
DEST="$DEST_DIR/$NAME"
mkdir -p "$DEST_DIR"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  cur=$(readlink "$DEST" 2>/dev/null || echo "$DEST")
  if [ "$cur" = "$SKILL_SRC" ]; then echo "✓ 已是最新: $DEST -> $SKILL_SRC"; exit 0; fi
  if [ "$FORCE" = 1 ]; then
    mv "$DEST" "$DEST_DIR/${NAME}.legacy.$(date +%s 2>/dev/null || echo bak)" 2>/dev/null \
      || rm -rf "$DEST"
    echo "⚠ 旧 $NAME 已挪走(.legacy)"
  else
    echo "✗ $DEST 已存在且指向 $cur" >&2
    echo "  要接管这个名字: bash install.sh --force(旧的备份为 .legacy)" >&2
    echo "  或装成别名:     bash install.sh --name harness-workflow-next" >&2
    exit 1
  fi
fi

ln -sfn "$SKILL_SRC" "$DEST"
echo "✓ 已安装: $DEST -> $SKILL_SRC"
echo "  现在 Claude 可调用 Skill($NAME)。脚本/hook 由 init.sh 进每个项目。"
echo "  自检: bash $SRC/scripts/doctor.sh(在已 init 的项目里)"
