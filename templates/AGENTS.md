<!-- doc-status: rules · owner: 人工 · 触发: 命令/红线/工作流变更 -->
# Agent 指南

> 唯一事实源（Codex/Cursor/Aider 直接读；Claude 经 CLAUDE.md stub 读）。
> 红线由本地 git hooks 强制（不靠自觉）；harness 不创建 GitHub Actions。其余是约定。优先级：本文件 > docs/WORKFLOW.md > 单次指令。

## 命令
- 构建: <TODO>
- 测试: <TODO>
- Lint: <TODO>

## 禁区
- 不提交 .env / secrets/；不直推 main/master（开 PR）
- 不新增/修改 `.github/workflows/*`；用户明确要求时才用一次性授权开关并留 `Workflow-Authorized:` trailer
- 高危命令先确认：force-push、reset --hard、rm -rf、改 .githooks/、curl|sh

## Commit 边界
- 测试不过不 commit
- light（可一键 revert + 不出本模块）→ commit 后问要不要 push
- full（跨模块/schema/CI/依赖）→ 先列计划等确认，commit 后不 push

## Mode
loose   <!-- loose: commit 后自动推（非 main）。strict: 计划→确认→commit，不推。 -->

## 接活前必读
docs/WORKFLOW.md（怎么干）、docs/PROJECT.md（项目地图；stale 就看 git log -20）

## 何时写 memory（commit-msg hook 强制）
- 修了非平凡 bug → docs/memory/cases/；非显然取舍 → docs/memory/decisions/
- 没什么可记 → commit 带 `Memory: none`

## 反模式区（季度清理，保持本文件短）
<!-- 例：2026-05 某 agent 老绕过 X；修好后此行可删 -->
