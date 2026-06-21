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
info() { echo "  · $1"; }   # 中性提示,不计入缺项

echo "harness-workflow 冷启动自检 @ $ROOT"

# 1. 必备文件(任何工具接手都要读的)
for f in AGENTS.md CLAUDE.md docs/WORKFLOW.md docs/PROJECT.md; do
  [ -f "$f" ] && ok "存在 $f" || bad "缺 $f(新工具无法读懂项目)"
done

# 2. hooks 三件 + scripts
for f in .githooks/pre-commit .githooks/commit-msg .githooks/pre-push scripts/verify-memory.sh scripts/gate-lib.sh; do
  [ -f "$f" ] && ok "存在 $f" || bad "缺 $f"
done

# 3. hooks 是否激活(本地 git config,不随 clone 走——这里正是提醒点)。
#    云端 gate 默认不装后,本地 hook 是默认且唯一的强制层 → 追踪"是否至少有一层在保护"。
protected=0
hp=$(git config --local --get core.hooksPath 2>/dev/null || true)
if [ "$hp" = ".githooks" ]; then ok "core.hooksPath=.githooks(本地 hook 已激活)"; protected=1
else warn "core.hooksPath 未设为 .githooks —— 本 clone 的本地 hook 没激活,跑 init.sh 或 git config core.hooksPath .githooks"; fi

# 3b. husky 场景:harness 红线是否接进 .husky/(init 会自动接 commit-msg/pre-commit)
if [ -d .husky ]; then
  if grep -q 'harness-workflow' .husky/commit-msg 2>/dev/null; then ok "husky 已接入 harness 红线(.husky/commit-msg)"; protected=1
  else warn "检测到 husky 但 harness 红线未接入 —— 跑 init.sh 自动接,或手动在 .husky/commit-msg 加 'bash .githooks/commit-msg \"\$@\"'"; fi
fi

# 4. 云端 CI gate 是【可选】兜底(默认不装,避免烧 Actions 额度)。装了就提示,没装不算缺项。
if [ -f .github/workflows/harness-gate.yml ]; then ok "云端 CI gate 已装(harness-gate.yml,跨工具不可绕兜底)"; protected=1
else info "云端 CI gate 未装(可选;默认不装省 Actions 额度。需服务端兜底:mkdir -p .github/workflows && cp templates/workflow-harness-gate.yml .github/workflows/harness-gate.yml)"; fi

# 4b. 两层全无 = 这个 clone 完全不受 harness 保护(红线/证据门一个都不会触发)。这是真缺项,fail。
[ "$protected" = 1 ] || bad "本 clone 既没激活本地 hook、也没装云端 gate —— harness 红线/证据门【完全不生效】。至少跑一次 init.sh(或 git config core.hooksPath .githooks)。"

# 5. 入口行数治理通过
if [ -x scripts/verify-governance.sh ]; then
  if bash scripts/verify-governance.sh >/dev/null 2>&1; then ok "入口文件行数在限内"; else bad "入口文件超行数上限(跑 scripts/verify-governance.sh 看详情)"; fi
fi

if [ "$fail" -eq 0 ]; then echo "→ 健康:新工具/新 clone 可仅凭本 repo 接手。"; else echo "→ 有缺项:补齐后新工具才能冷启动接手。"; fi
exit "$fail"
