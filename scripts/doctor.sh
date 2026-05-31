#!/usr/bin/env bash
# doctor.sh — 冷启动自检：换一台机器 / 换一个工具(Cursor/Aider/Codex)只凭这个 repo,
# 能不能把 harness 正确接手起来?这是单人版的"成熟度门槛"。
# 退出码非 0 = 有缺项;逐项打印 ✓/✗。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"
fail=0
ok()   { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=1; }
warn() { echo "  ⚠ $1"; }

echo "harness-workflow 冷启动自检 @ $ROOT"

# 1. 必备文件(任何工具接手都要读的)
for f in AGENTS.md CLAUDE.md docs/WORKFLOW.md docs/PROJECT.md; do
  [ -f "$f" ] && ok "存在 $f" || bad "缺 $f(新工具无法读懂项目)"
done

# 2. hooks 三件 + scripts
for f in .githooks/pre-commit .githooks/commit-msg .githooks/pre-push scripts/verify-memory.sh scripts/gate-lib.sh; do
  [ -f "$f" ] && ok "存在 $f" || bad "缺 $f"
done

# 3. hooks 是否激活(本地 git config,不随 clone 走——这里正是提醒点)
hp=$(git config --local --get core.hooksPath 2>/dev/null || true)
if [ "$hp" = ".githooks" ]; then ok "core.hooksPath=.githooks(本地 hook 已激活)"
else warn "core.hooksPath 未设为 .githooks —— 本 clone 的本地 hook 没激活,跑 init.sh 或 git config core.hooksPath .githooks(CI 仍兜底)"; fi

# 4. CI 兜底存在(真正跨工具不变量)
[ -f .github/workflows/harness-gate.yml ] && ok "CI 兜底 harness-gate.yml 存在" || warn "缺 .github/workflows/harness-gate.yml —— 跨工具/绕过 hook 的不变量缺失"

# 5. 入口行数治理通过
if [ -x scripts/verify-governance.sh ]; then
  if bash scripts/verify-governance.sh >/dev/null 2>&1; then ok "入口文件行数在限内"; else bad "入口文件超行数上限(跑 scripts/verify-governance.sh 看详情)"; fi
fi

if [ "$fail" -eq 0 ]; then echo "→ 健康:新工具/新 clone 可仅凭本 repo 接手。"; else echo "→ 有缺项:补齐后新工具才能冷启动接手。"; fi
exit "$fail"
