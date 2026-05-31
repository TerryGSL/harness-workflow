#!/usr/bin/env bash
# init.sh — idempotently scaffold harness-workflow into the current git repo.
# Templates are user-owned (skip if present); scripts/hooks/CI are tool-owned (refreshed).
set -euo pipefail
HW_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$TARGET"

copy_if_absent() { # <src> <dst>
  if [ -e "$2" ]; then echo "跳过（已存在）: $2"
  else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "创建: $2"; fi
}

# --- user-owned templates (never overwrite) ---
copy_if_absent "$HW_SRC/templates/AGENTS.md"   "AGENTS.md"
copy_if_absent "$HW_SRC/templates/CLAUDE.md"   "CLAUDE.md"
copy_if_absent "$HW_SRC/templates/PROJECT.md"  "docs/PROJECT.md"
copy_if_absent "$HW_SRC/templates/WORKFLOW.md" "docs/WORKFLOW.md"
copy_if_absent "$HW_SRC/templates/aider.conf.yml"  ".aider.conf.yml"
copy_if_absent "$HW_SRC/templates/cursor-harness.mdc" ".cursor/rules/harness.mdc"
copy_if_absent "$HW_SRC/templates/workflow-harness-gate.yml" ".github/workflows/harness-gate.yml"
mkdir -p docs/memory/cases docs/memory/decisions
# Intentionally NOT created (minimalism): WORK.md (opt-in, parallel only),
# docs/memory/archive/ (lazy), .ai-mode (folded into AGENTS.md Mode line).

# --- tool-owned scripts + hooks (refreshed each init) ---
mkdir -p scripts .githooks
for s in gate-lib.sh verify-memory.sh verify-governance.sh ci-gate.sh stale-cases.sh memory-stats.sh doctor.sh; do
  [ -f "$HW_SRC/scripts/$s" ] && cp "$HW_SRC/scripts/$s" "scripts/$s" || true
done
chmod +x scripts/*.sh
for h in pre-commit commit-msg pre-push; do
  cp "$HW_SRC/githooks/$h" ".githooks/$h"; chmod +x ".githooks/$h"
done

# --- wire hooks without clobbering an existing hook manager ---
existing=$(git config --local --get core.hooksPath 2>/dev/null || true)
if [ -n "$existing" ] && [ "$existing" != ".githooks" ]; then
  echo "⚠ core.hooksPath 已是 '$existing' —— 不覆盖。"
  echo "  你现有的 hook 管理器保留。要两套都用就手动接："
  echo "    在你的管理器里调 .githooks/{pre-commit,commit-msg,pre-push}，"
  echo "    或运行: git config core.hooksPath .githooks   （会替换掉另一套）"
elif [ -d .husky ] || [ -f lefthook.yml ] || [ -f .pre-commit-config.yaml ]; then
  echo "⚠ 检测到已有 hook 管理器（husky/lefthook/pre-commit）。"
  echo "  不设 core.hooksPath。要改用本套：git config core.hooksPath .githooks"
else
  git config core.hooksPath .githooks
  echo "已设 core.hooksPath -> .githooks"
fi

cat <<'EOF'

harness-workflow 初始化完成。
  • 本地 hook 只对【这个 clone】生效（core.hooksPath 是本地 git config，
    不随 clone 传——每个 clone 要重跑 init.sh 或自己设 core.hooksPath）。
  • 真正不可绕过的不变量是 CI：.github/workflows/harness-gate.yml。
    把脚手架 commit + push，CI 才对所有工具/clone/PR 生效：
        git add -A && git commit -m "chore: 接入 harness-workflow

Memory: none" && git push
  • 进度就在 git log —— 没有状态文件要维护。
  • 干活流程看 docs/WORKFLOW.md。
  • 下一步：填 AGENTS.md 命令 + Mode 行（loose/strict），编辑 docs/PROJECT.md。
EOF
