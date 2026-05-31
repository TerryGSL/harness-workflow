---
name: harness-workflow
description: 持续开发工作流。代码任务(做/加/修/改/实现/重构/bug/接入)用它:按任务大小路由→给推荐管线指南→commit/CI 机械证据门保证按流程。它只调度现成插件(superpowers/codex/claude-mem),不重造、不写 team-* 角色、不搞 contracts。
---

# harness-workflow — router + 证据门

**怎么"保证按流程"**:不是靠你读这段(prose 会漂),是靠 **commit 带 `Harness-Type:` + git hook/CI 查证据 artifact**。下面是推荐怎么干,执行权在机械门。

## 接手任务先做
`bash scripts/state.sh show`(秒级恢复;丢了 `regen`)→ 必要时 `git log --oneline -20`。未接入(无 .harness/)→ 先 `bash <repo>/init.sh`。

## 路由(按影响范围+可逆性,判不准往重的放)
- **trivial**(单文件/可一键 revert/不碰 schema 接口依赖)→ 直接改+测+commit。
- **bug** → `superpowers:systematic-debugging` 定位 → 先写**会失败的测试** → 最小修复 → 回归。
- **refactor** → `superpowers:test-driven-development` 固化行为 → 小步改每步全绿 → 不混功能。
- **feature/大改** → 推荐管线:`superpowers:brainstorming` 脑暴 → `writing-plans` 计划 → `subagent-driven-development` 分任务实现 → `codex review` 独立审查 → `verification-before-completion` 验证 → claude-mem(装了的话)记忆 → commit。

> 这些是**指南**;feature 的"完整阶段"对大改有用,小改别硬上。claude-mem 没装就用 docs/memory/。

## 证据门(机械保证,commit 必须满足否则 commit/CI 拒)
改代码的 commit 必须声明 `Harness-Type: trivial|bug|feature|refactor`,并按类型带证据:
- **bug** → 同 commit 含测试文件,**或** `No-Repro: <原因>`
- **feature** → `Plan: <计划文件>`(或同 commit 含 docs/**plan*.md) **且** `Reviewed-by: codex`(过审留痕)
- **refactor** → `Behavior-Unchanged: true`(测试绿由 pre-push/CI 验)
- **trivial** → 无额外证据
回退提交(`Revert`/`Rollback`)豁免。memory 仍由 commit-msg 门要求(`Memory:` 或 case)。

## 分任务用 subagent(context/state 同步靠 artifacts,不靠传对话)
派 subagent 跑并行任务时(复用 `superpowers:subagent-driven-development`):
- **派发前(in)**:`bash scripts/brief.sh "<子任务>" "<文件边界>"` 生成自包含简报塞进 subagent prompt(含 state.json+近期 git+地图+相关 memory)。零上下文也对齐。
- **边界**:one file one owner,各 subagent 文件不相交 + 各自分支;同文件必串行。
- **回收(out)**:subagent 只回 结论+证据(改了啥/测试结果/决策),不回脏中间态。
- **同步(state)**:主 agent synthesize → `scripts/state.sh set` 更新 + 勾 plan checkbox + commit(git 成共享真相)+ 必要时写 decision。

## 失败/降级
阶段失败且 3 次内修不好 → `git restore` 本步(留前面成果)+ 记 case + 问用户。连续失败 ≥2 次停下。
**degraded 不静默**:插件没装(codex/superpowers/claude-mem 缺)→ 该步手工做并**明说"降级了"**,不假装。

## 护栏(机械兜底)
git hooks(密钥/不推 main/memory/证据门)+ CI(ci-gate 服务端不可绕)+ verify-governance(入口行数封顶)。**流程可漂,红线和证据门越不过。** state.json 只是恢复缓存,门禁不读它。
