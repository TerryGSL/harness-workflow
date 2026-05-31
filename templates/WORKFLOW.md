# WORKFLOW — 怎么干活（任何工具，session 开头先读这个）

> 这是"流程纪律"，不是死规矩。基础设施（密钥/不推 main/memory）由 git hook + CI 强制；
> 这里讲的是"拿到一个任务，按什么步骤做"。判不准任务属于哪档，就往更重的那档放。

## 任务分级（按影响范围 + 可逆性，不按行数）
- **trivial**：单文件、可一键 revert、不碰 schema/接口/依赖（typo、文案、注释、配置数值微调）
- **bug**：修复已有行为的缺陷
- **feature**：新增功能 / 跨模块 / 改接口 / 改 schema
- **refactor**：不改外部行为，只改内部结构

---

## trivial → 直接做
改 → 跑测试 → commit（没有值得记的坑就在 commit 信息带一行 `Memory: none`）。
别上计划、别上审查，那是噪音。

## bug → 五步 TDD（顺序不可颠倒）
1. **定位**：先复现，读相关代码，形成根因假设——*别急着改*。
2. **写失败测试**：先写一个能暴露这个 bug 的测试，**必须先 FAIL**，证明你抓对了。
3. **最小修复**：只让那个测试过，不顺手重构、不扩大范围。
4. **回归**：跑全量测试，全绿才算修好。
5. **收尾**：commit + 写 `docs/memory/cases/<日期>-<slug>.md`（根因 + 修法；commit-msg hook 会催）。

连续 3 轮还修不好 → 停，当 feature 重新设计，别在原地硬磕。

## feature → 轻量分阶段
1. **设计**：一段话讲清——做什么 / 影响哪些模块 / 风险点在哪。复杂的先 `superpowers:brainstorming`。
2. **计划**：列 bite-size 步骤；规模大的用 `superpowers:writing-plans` 落成计划文件。
3. **实现**：每步 TDD（先测后码），频繁 commit，别攒大 commit。
4. **审查**：diff 过一遍 `/codex review` 或 `strict-reviewer`——*别自己拍板说没问题*。
5. **收尾**：有非显然的架构取舍就写 `docs/memory/decisions/<日期>-<slug>.md` + commit。

> 不自建 PD/架构师/QA 角色 agent——审查/调试直接用现成的 `/codex`、`superpowers`、`strict-reviewer`。

## refactor → 行为保持
1. **先固化测试**：没有覆盖就先补，把"当前行为"锁住。
2. **小步改**：每步改完跑全量测试，必须保持全绿。
3. **不混功能变更**：重构和加功能分开做、分开 commit。

---

## 失败回退（任何阶段卡住、3 次内修不好）
1. `git diff --stat` 看本步改了哪些文件。
2. `git checkout -- <本步文件>` 回退本步（**保留前面阶段的成果**）。
3. 写 `docs/memory/cases/` 记：失败上下文 + 试过的方案 + 给下次的提示。
4. 问用户：调方案 / 拆小 / 放弃。

## degraded 不静默
该用的工具缺了（没装 codex、某 skill 不在）→ **手工做，并明确告诉用户"这一步降级了"**，
绝不假装做了。静默兜底比不做更糟。

## 多 agent 并行
git worktree + 分支天然隔离；只有 2+ agent 同 repo 并行时才建 `WORK.md`，开工前 append 一行 claim。
单人单 agent 用不到。进度永远看 `git log`，没有状态文件要维护。
