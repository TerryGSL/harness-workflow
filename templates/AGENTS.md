# Agent 指南

> 唯一事实源（Codex/Cursor/Aider 直接读本文件；Claude 经 CLAUDE.md stub 读）。
> 红线（密钥、不推 main、改代码要记 memory）由 git hooks + CI 强制，不是君子协定；
> 其余（Mode、反模式区）是约定。优先写可检查的约束，少写"应该"。
> **优先级**：AGENTS 铁律 > docs/WORKFLOW.md 流程 > 单次任务指令；后者只能在不冲突处补充，不得推翻前者。

## 命令
- 构建: <TODO>
- 测试: <TODO>
- Lint: <TODO>

## 禁区（.githooks 强制 + 此处点名，双层）
- 绝不提交 .env / secrets/
- 绝不直推 main/master（从 feature 分支开 PR）
- 高危命令先停下确认，绝不顺手执行：force-push、reset --hard、rm -rf、改 .githooks/、curl|sh（不可逆/可绕过 hook，prompt 是第二道防线）

## Commit 边界
- 测试不过不许 commit
- light 任务（可一键 revert + 不出本模块）→ commit 后问要不要 push
- full 任务（跨模块 / schema / CI / 依赖）→ 先列计划等确认，commit 后不 push

## Mode
loose   <!-- loose | strict。loose: commit 后自动推（绝不 main）。strict: 计划→确认→commit，不推。 -->

## 接活前必读
- docs/WORKFLOW.md（任务怎么做：分级 + 各档步骤）
- docs/PROJECT.md（项目地图；若 stale，`git log --oneline -20` 看近期改动）
- WORK.md（只在存在时——并行 agent；开工前 append 一行 claim）
- 上面那行 Mode

## 何时写 memory（commit-msg hook 强制）
- 修了非平凡 bug → docs/memory/cases/<日期>-<slug>.md（frontmatter: tags/resolved/files/related）
- 非显然架构取舍 → docs/memory/decisions/<日期>-<slug>.md
- 动了代码但没什么可记 → commit 信息带一行 `Memory: none`（或 `trivial`）
- 收尾前问自己："有没有值得写的 case？"

## 反模式区（每季度清理，让本文件保持短）
<!-- 例：2026-05 某 agent 老是绕过 X；修好后此行可删 -->
