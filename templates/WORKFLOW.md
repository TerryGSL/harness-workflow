<!-- doc-status: rules · owner: 人工 · 触发: 工作流规则变更 -->
# WORKFLOW — 参考卡（提示，不是引擎）

> 红线（密钥 / 不推 main / 改代码记 memory / 测试）由本地 git hook **机械强制**，不靠你读这里。CI 是可选服务端兜底，默认不装。
> 下面是提示，会被漂移——判不准任务档位就往重的那档放。

## 任务分级（按影响范围 + 可逆性）
- **trivial**：单文件、可一键 revert、不碰 schema/接口/依赖
- **bug**：修已有行为的缺陷
- **feature**：新增 / 跨模块 / 改接口 / 改 schema
- **refactor**：不改外部行为，改内部结构

## 每档最关键的一条
- **trivial** → 直接改 + 跑测试 + commit
- **bug** → **先写一个会失败的测试**（证明抓对了）再修；连续 2 次修不好就停下找人
- **feature** → 完整管线(Claude 由指挥家 skill 驱动;其它工具按此手动)：脑暴(superpowers:brainstorming)→ 计划(writing-plans)→ 分任务实现(subagent-driven-development)→ **独立审查(`/codex review`)** → 验证 → 记忆 → commit。别自己说没问题。
- **refactor** → 先固化测试锁住行为，小步改、每步全绿，不混功能变更

## 证据门（机械保证"按流程"——commit/CI 拒不合规）
改代码的 commit 必须带 `Harness-Type: trivial|bug|feature|refactor`，并按类型带证据：
bug→测试或 `No-Repro:`；feature→`Plan:`+`Reviewed-by:`+`Brainstormed-by:`；refactor→`Behavior-Unchanged: true`。回退提交豁免。
（这才是"保证按流程"，不靠你读上面的提示。）

## degraded 不静默
工具缺了 / 步骤失败 → 手工做并明说"这步降级了"，不假装做了。

## 多 agent 并行（没并行就忽略）
各自 worktree + 分支、文件不相交；失败收尾要么 commit 要么 `git restore`，不留脏树。

## 文档不变死文件（doc-status 自描述 + 机械门）
每个文档**首行声明 `<!-- doc-status: X -->`**,门(`verify-doc-freshness.sh`)强制——没声明=失败,逼你给每个文件「谁维护」的答案。**「冻结」和「烂掉」就此区分开。** 状态:
- `generated`：机器生成(code-map.json / records-index.md),lockfile 校验同步,**人别手改**。
- `living`：随现实变(PROJECT.md / DEV-PLAN.md),supervisor 每轮刷;stale 由 supervisor 建任务,不硬卡。
- `rules`：稳定治理(AGENTS/CLAUDE/WORKFLOW),只在规则变时改。
- `curated`：稀疏人工知识(memory/summary·cases·decisions),**空也合法**。
- `frozen`：已完成的 spec / 交接文档(docs/specs/* / 跨 agent 协调),冻结存档,不维护。
- `archived`：退役 → 移到 docs/archive/。
新增文档**第一件事**:首行写对 doc-status。机器正源永远优先散文(文件清单看 code-map,不手抄)。
