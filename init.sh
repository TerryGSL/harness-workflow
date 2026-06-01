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
copy_if_absent "$HW_SRC/templates/state.json.tmpl" ".harness/state.json"
copy_if_absent "$HW_SRC/templates/aider.conf.yml"  ".aider.conf.yml"
copy_if_absent "$HW_SRC/templates/cursor-harness.mdc" ".cursor/rules/harness.mdc"
copy_if_absent "$HW_SRC/templates/workflow-harness-gate.yml" ".github/workflows/harness-gate.yml"
mkdir -p docs/memory/cases docs/memory/decisions .harness/records
# 沉淀层:change-index(JSONL,append 安全) + 跨需求稳定经验摘要
[ -f .harness/change-index.jsonl ] || : > .harness/change-index.jsonl
copy_if_absent "$HW_SRC/templates/memory-summary.md" "docs/memory/summary.md"
# Intentionally NOT created (minimalism): WORK.md (opt-in, parallel only),
# docs/memory/archive/ (lazy), .ai-mode (folded into AGENTS.md Mode line).

# --- tool-owned scripts + hooks (refreshed each init) ---
mkdir -p scripts .githooks
for s in gate-lib.sh verify-memory.sh verify-evidence.sh verify-governance.sh ci-gate.sh doctor.sh state.sh brief.sh record.sh; do
  [ -f "$HW_SRC/scripts/$s" ] && cp "$HW_SRC/scripts/$s" "scripts/$s" || true
done
chmod +x scripts/*.sh
for h in pre-commit commit-msg pre-push; do
  cp "$HW_SRC/githooks/$h" ".githooks/$h"; chmod +x ".githooks/$h"
done

# --- wire hooks without clobbering an existing hook manager ---
existing=$(git config --local --get core.hooksPath 2>/dev/null || true)
# husky 优先判断:现代 husky 把 core.hooksPath 指到 .husky/_，必须在 hooksPath 判断【之前】判，
# 否则真实 husky 会被"非空 hooksPath 保守退出"挡掉。但【仅当】hooksPath 为空或本身指 husky 才自动接——
# 若指向别处(如 .myhooks),即便有 .husky 目录也不接(git 实际跑别处,接了无效;codex 抓到)→ 落保守分支。
husky_auto=0
if [ -d .husky ]; then case "$existing" in ""|.husky|.husky/_) husky_auto=1 ;; esac; fi
if [ "$husky_auto" = 1 ]; then
  echo "⚠ 检测到 husky —— 自动把 harness 核心红线接进 .husky/（幂等,不覆盖你已有内容）。"
  for h in pre-commit commit-msg; do
    f=".husky/$h"
    [ -f "$f" ] || printf '#!/usr/bin/env sh\n' > "$f"
    if grep -qF 'harness-workflow（勿删' "$f" 2>/dev/null; then   # 精确 marker,不是宽松 grep 关键词
      echo "  • .husky/$h 已接入,跳过"
    else
      {
        echo ''
        echo '# >>> harness-workflow（勿删；密钥/memory/证据门）>>>'
        echo 'bash "$(git rev-parse --show-toplevel)/.githooks/'"$h"'" "$@" || exit 1'
        echo '# <<< harness-workflow <<<'
      } >> "$f"
      chmod +x "$f"; echo "  ✓ 已接入 .husky/$h"
    fi
  done
  echo "  ⚠ pre-push(测试+风险分级)读 git stdin,自动 append 会破坏 refs 透传——没动它。"
  echo "    要本地也跑:在 .husky/pre-push 手动加 'bash .githooks/pre-push \"\$@\"';否则靠 CI 兜底。"
elif [ -n "$existing" ] && [ "$existing" != ".githooks" ]; then
  echo "⚠ core.hooksPath 已是 '$existing' —— 不覆盖。"
  echo "  你现有的 hook 管理器保留。要两套都用就手动接："
  echo "    在你的管理器里调 .githooks/{pre-commit,commit-msg,pre-push}，"
  echo "    或运行: git config core.hooksPath .githooks   （会替换掉另一套）"
elif [ -f lefthook.yml ] || [ -f .pre-commit-config.yaml ]; then
  echo "⚠ 检测到 lefthook / pre-commit-config —— 配置格式各异,不自动改。"
  echo "  要本地红线:在你的管理器里调 .githooks/{pre-commit,commit-msg,pre-push},或 git config core.hooksPath .githooks。"
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
