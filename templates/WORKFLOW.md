# WORKFLOW — 怎么干活（任何工具，session 开头先读这个）

> 这是"流程纪律"，不是死规矩。基础设施（密钥/不推 main/memory）由 git hook + CI 强制；
> 这里讲的是"拿到一个任务，按什么步骤做"。判不准任务属于哪档，就往更重的那档放。
>
> **续写优先**：被中断 / 接力 / 换会话续做时，直接从断点续写并报告进度——不道歉、不复述前文、剩余工作拆小。

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

## 完成判据（DoD）——完成不由干活的自己宣布，以独立验证为准
- **trivial**：测试绿。
- **bug**：回归全绿 + case 已写 + 无新增 lint 错 + 工作树干净。
- **feature**：测试绿 + **必须过一道 `/codex review` 或 strict-reviewer 独立验证** + 有取舍则写 decision。
- **refactor**：行为保持（测试全绿且未改测试断言）+ 至少跑一次回归当独立验证。

## 失败回退 / 熔断（任何阶段卡住）
1. `git diff --stat` 看本步改了哪些文件。
2. `git checkout -- <本步文件>` 回退本步（**保留前面阶段的成果**）。
3. 写 `docs/memory/cases/` 记：失败上下文 + 试过的方案 + 给下次的提示。
4. 问用户：调方案 / 拆小 / 放弃。

**熔断**：同一步骤（写测试 / 修复 / review 迭代）连续失败 ≥2 次 → 停下、记下已试过的失败假设、找用户。禁止无记忆重试原地烧 token。

**故障分类处置**（错误路径就是主路径，提前想好）：
- 被中断（半挂 edit）→ 要么 commit 要么 `git restore`，不留半挂。
- 输出截断 → 从断点续写，不重头来、不复述。
- 崩溃/换会话重启 → 按最近 commit 重建"上一轮在干什么"（git log 是 rollout）。
- 连续失败 → 见上面熔断。

## degraded 不静默
该用的工具缺了（没装 codex、某 skill 不在）→ **手工做，并明确告诉用户"这一步降级了"**，
绝不假装做了。静默兜底比不做更糟。

## 多 agent 并行约定（1-3 agent；单人单 agent 跳过）
多代理是"给不确定性分区"，不是提速。约定：
- **边界不相交**：每个 agent 限定不重叠的文件/目录 + 各自 worktree + 各自分支。同一文件禁止两个 agent 并行（git merge 解文本冲突，解不了语义竞态）。
- **子 agent 只回结论+证据**，不把中间脏状态/临时文件写回主线程。
- **主 agent 必须 synthesize**：亲自读懂子结果，给出带"具体文件/行/改动"的下一步，禁止"based on your findings"式转发。
- **收尾不留脏树**：失败/中止的并行任务，要么完整 commit，要么 `git restore` 回滚——不留半挂工作区。谁派发谁负责 cleanup。
- 只有 2+ agent 同 repo 并行时才建 `WORK.md` 开工前 append claim。进度永远看 `git log`。

## session 头三件套 + 上下文卫生
- **接手任何 repo / 续做时先读**：`git log --oneline -20` + `docs/PROJECT.md` + 相关 `docs/memory/cases`。这是"换工具立即读懂状态"的人肉重建。
- **长任务上下文卫生**：阶段产出落 docs（设计/计划写文件，别全留对话）；超长时主动 compact，并在 PROJECT.md 留指针，让下一段/下一个 agent 能接。

## memory 治理（写侧由 commit-msg hook 强制，这里是判断 + 读侧）
- **什么不该写**：trivial 改动不入 case；只有"可复用的坑"进 cases、"非显然取舍"进 decisions。别把 plan/task 当 memory。
- **读侧先 verify**：据 case/decision 行动前先核对现状；与现状冲突时信任现状，并就地修正旧记忆（记忆会过期）。
