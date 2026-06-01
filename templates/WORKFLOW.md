# WORKFLOW — 参考卡（提示，不是引擎）

> 红线（密钥 / 不推 main / 改代码记 memory / CI 跑测试）由 git hook + CI **机械强制**，不靠你读这里。
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
