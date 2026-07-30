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
本地 git hooks(密钥/不推 main/memory/证据门)+ verify-governance(入口行数封顶)。**GitHub Actions 永远 opt-in**：harness 不创建/修改 `.github/workflows/*`；只有用户明确要求时才可一次性设置 `HARNESS_ALLOW_GITHUB_WORKFLOWS=1`，且 commit 必须带 `Workflow-Authorized: <授权说明>`。`ci-gate.sh` 是可显式调用的规则脚本，不附带 workflow。**流程可漂,红线和证据门越不过。** state.json 只是恢复缓存,门禁不读它。

## 文档自维护(治死文档,机械不靠自觉)
**原则:烂不掉的交给机器(自动生成+lockfile 校验);讲"为什么"的贴着代码且窄范围。** 散文文档必漂,生成的事实图不漂。
- **code-map(机器事实图)**:`gen-code-map.mjs` 扫 src/ 出 `docs/code-map.json`(文件树/exports/imports/route/locales/配对测试,**无时间戳=确定性**)。`verify-code-map.sh --fix`(pre-commit 自动重生成+staged,**永不挡循环**)/ 严格(ci-gate 抓绕过)。
- **@purpose(文件职责)+ 架构摘要 —— 治"不知道每个文件干啥"**:边界目录(`.harness/code-map.config.json` 的 `boundary`)文件首行写 `/** @purpose <一句职责> */`。`verify-purpose.sh` **棘轮门**(缺失路径集只减不增,基准 `.harness/purpose-baseline`):新增/改动边界文件没写就 pre-commit/CI 拦,补旧的不能抵新缺。`gen-architecture-summary.mjs` 从 code-map+@purpose 机械生成**人类可读** `docs/ARCHITECTURE.md`(顶层版图/子系统职责表/路由表),ci `cmp` 防手改漂移。
- **记忆合一**:`.harness/records/` = 正源;`distill-records.sh` 蒸馏成 `docs/memory/records-index.md`(records 索引)**+ `docs/memory/summary.md`**(从 cases/decisions 蒸馏的"跨需求先读"索引,**generated 不再是 human 空占位**)。`verify-memory.sh` 认 `Harness-Record` 即满足 memory 门。
- **活文档保鲜门 —— 治"文档停在几天前"**:`verify-doc-freshness.sh`(死链/locale 漂/缺 doc-status 头)pre-commit 早警告 + ci 硬 fail。`verify-living-docs.sh`+`.harness/living-docs.json`:标 `living` 的文档**必须注册 triggers+SLA**,落后触发源提交太多 → warn(pre-commit)/fail(ci);不维护就降 frozen/curated。`verify-doc-sprawl.sh`:根层 *.md 白名单门(防文档堆根目录复发)。
- **事实源防污染**:`strip-mem-injection.sh`(pre-commit 从暂存 blob 剥 claude-mem 注入块,入库恒干净)+ `relocate-mem-injection.sh`(SessionStart hook,把注入挪到 gitignored `.harness/runtime/`,工作树也干净)→ AGENTS.md/CLAUDE.md 不被周期性污染。
- 用 autonomous-dev-loop 时,supervisor 每轮跑 `gen-code-map + gen-architecture-summary + distill-records + verify-doc-freshness + verify-purpose + verify-living-docs`;**@purpose 由 commit 时棘轮门强制(supervisor 不改 src,消除"要补却禁改"的矛盾)**。
