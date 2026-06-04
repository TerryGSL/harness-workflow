---
name: harness-workflow
description: 持续开发工作流。代码任务(做/加/修/改/实现/重构/bug/接入)用它:按任务大小路由→给推荐管线指南→commit/CI 机械证据门保证按流程。它只调度现成插件(superpowers/codex/claude-mem),不重造、不写 team-* 角色、不搞 contracts。
---

# harness-workflow — router + 证据门

**怎么"保证按流程"**:不是靠你读这段(prose 会漂),是靠 **commit 带 `Harness-Type:` + git hook/CI 查证据 artifact**。下面是推荐怎么干,执行权在机械门。

## 接手任务先做
**先查记忆**(装了 claude-mem 就用):`mem-search` / query claude-mem 找"上次怎么做 / 踩过啥坑"(跨 session 对话记忆)→ `bash scripts/state.sh show`(秒级恢复;丢了 `regen`)→ 读 `.harness/change-index.jsonl`(渐进下钻)+ `docs/memory/` case·decision → 必要时 `git log --oneline -20`。未接入 → 先 `bash <repo>/init.sh`。

> **记忆三层,各干各的,别当替代品**:claude-mem = 跨 session 对话 observation(插件自动记,接手时主动 query)· `.harness/records/` = 每需求沉淀(record.sh,git-tracked)· `docs/memory/` = case/decision(踩坑·架构取舍,git-tracked)。

## 沉淀(机械强制,治"每轮啥也不留")
非 trivial 任务**开工先** `id=$(bash scripts/record.sh start <type> <slug>)` 建 `.harness/records/<id>.md`,边做边填 What/Changed&Why/Tests/Decisions/Followups。**commit 必须带 `Harness-Record: <id>` 且同 commit 改了该 record.md**,否则 commit-msg/CI 拒。收尾 `bash scripts/record.sh done <id>`(校验段落非空 + append change-index)。trivial 免。

## 路由(按影响范围+可逆性,判不准往重的放)
- **trivial**(单文件/可一键 revert/不碰 schema 接口依赖)→ 直接改+测+commit。
- **bug** → `superpowers:systematic-debugging` 定位 → 先写**会失败的测试** → 最小修复 → 回归。
- **refactor** → `superpowers:test-driven-development` 固化行为 → 小步改每步全绿 → 不混功能。
- **feature/大改** → 推荐管线:`superpowers:brainstorming` 脑暴 → `writing-plans` 计划 → `subagent-driven-development` 分任务实现 → `codex review` 独立审查 → `verification-before-completion` 验证 → claude-mem(装了的话)记忆 → commit。

> 这些是**指南**;feature 的"完整阶段"对大改有用,小改别硬上。脑暴/设计任务**必须**走 `superpowers:brainstorming`(别手动脑暴),feature commit 由证据门查 `Brainstormed-by:` 留痕。

## 证据门(机械保证,commit 必须满足否则 commit/CI 拒)
改代码的 commit 必须声明 `Harness-Type: trivial|bug|feature|refactor`,并按类型带证据:
- **bug** → 同 commit 含测试文件,**或** `No-Repro: <原因>`
- **feature** → `Plan: <计划文件>`(或同 commit 含 docs/**plan*.md) **且** `Reviewed-by: codex`(过审留痕) **且** `Brainstormed-by: <superpowers:brainstorming | none:理由>`(脑暴先行留痕;没走脑暴就 `none:` 写明原因)
- **refactor** → `Behavior-Unchanged: true`(测试绿由 pre-push/CI 验)
- **trivial** → 无额外证据
回退提交(`Revert`/`Rollback`)豁免。memory 仍由 commit-msg 门要求(`Memory:` 或 case)。

## 任务板 + 多 agent 并行(都挂在 record.md 的 `## Tasks`)
- **任务板=record.md 的 `## Tasks`**:把需求拆成 `- [ ] N <任务>`;开发时用 Claude **TodoWrite** 做实时视图,做完一条就把 record.md 里勾成 `- [x]`(进度持久进 git,`bash scripts/record.sh tasks <id>` 看 X/N)。
- **并行 subagent**(复用 `superpowers:subagent-driven-development`,多任务也可 `task-dispatcher`):每个 sub-agent **认领一条任务**,在该行标 `@owner wt=<worktree>`;各自 worktree、**文件不相交**(one file one owner,同文件必串行)。
- **派发前(in)**:`bash scripts/brief.sh "<该任务>" "<文件边界>"` 生成自包含简报塞进 subagent prompt(含 state+近期 git+memory),零上下文也对齐。
- **回收(out)**:sub-agent 只回 结论+证据(改了啥/测试/决策),不回脏中间态。
- **同步(state)**:主 agent synthesize → 勾掉 record.md 对应 task + 必要时写 Decisions/decision → commit(带 `Harness-Record:<id>`,git 成共享真相)。

## 失败/降级
阶段失败且 3 次内修不好 → `git restore` 本步(留前面成果)+ 记 case + 问用户。连续失败 ≥2 次停下。
**degraded 不静默**:插件没装(codex/superpowers/claude-mem 缺)→ 该步手工做并**明说"降级了"**,不假装。

## 护栏(机械兜底)
git hooks(密钥/不推 main/memory/证据门)+ CI(ci-gate 服务端不可绕)+ verify-governance(入口行数封顶)。**流程可漂,红线和证据门越不过。** state.json 只是恢复缓存,门禁不读它。

## 文档自维护(治死文档,机械不靠自觉)
**原则:烂不掉的交给机器(自动生成+lockfile 校验);讲"为什么"的贴着代码且窄范围。** 散文文档必漂,生成的事实图不漂。
- **code-map**:`scripts/gen-code-map.mjs` 扫 src/ 出 `docs/code-map.json`(事实:文件树/exports/imports/route 方法/locales/配对测试,**无时间戳=确定性**)。零上下文 agent 冷启动读它,不读散文 map。`scripts/verify-code-map.sh --fix`(pre-commit:src 改了自动重生成+staged,**永不挡循环**)/ 严格(ci-gate 抓绕过)。文件职责 = 文件头 `/** @purpose ... */`,只对边界目录软统计(`.harness/code-map.config.json` 配 `{"boundary":[...]}`),不全量硬卡。
- **记忆合一**:`.harness/records/` = 正源;`scripts/distill-records.sh` 蒸馏成 `docs/memory/records-index.md`。`verify-memory.sh` 认 `Harness-Record` 即满足 memory 门(记录就是记忆,不必凑 `Memory:` 行)。
- **文档保鲜**:`scripts/verify-doc-freshness.sh`(纸面承诺死链/locale 漂移/生成产物缺失),跑在 ci-gate + supervisor 每轮(机械,不靠自觉)。
- 用 autonomous-dev-loop 时,把 supervisor 指令(AUTODEV-SUPERVISOR.md)绑一条:每轮跑 `gen-code-map + distill-records + verify-doc-freshness`,@purpose 分批补边界文件。
