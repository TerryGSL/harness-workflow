#!/usr/bin/env bash
# brief.sh "<子任务描述>" [文件边界glob...] — 组装一份自包含 subagent briefing。
# 用途：派 subagent 前 `brief.sh "实现X" "src/auth/**"` 把输出塞进 subagent prompt，
# 让它零上下文也能对齐当前状态。同步靠 repo artifacts，不靠传对话上下文。只读。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd); cd "$ROOT"
task="${1:-<未指定子任务>}"; shift 2>/dev/null || true
echo "## 子任务"; echo "$task"; echo
echo "## 文件边界（one file one owner，只动这些，别碰别处）"
[ "$#" -gt 0 ] && printf '%s\n' "$@" || echo "（未指定，主 agent 应指定不相交边界）"; echo
echo "## 当前状态（.harness/state.json，恢复缓存）"
[ -f .harness/state.json ] && cat .harness/state.json || echo "（无）"; echo
echo "## 最近进度（git log -10）"; git log --oneline -10 2>/dev/null || echo "（无提交）"; echo
echo "## 项目地图（docs/PROJECT.md）"; [ -f docs/PROJECT.md ] && sed -n '1,30p' docs/PROJECT.md || echo "（无）"; echo
echo "## 相关决策/坑（docs/memory）"; ls docs/memory/cases docs/memory/decisions 2>/dev/null | head -20 || echo "（无）"; echo
echo "## 回传要求"
echo "只回：改了哪些文件 + 测试结果 + 关键决策。不要回中间脏状态。完成后主 agent 会 synthesize 并更新 state.json/plan/commit。"
