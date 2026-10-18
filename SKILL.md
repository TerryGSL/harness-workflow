---
name: harness-workflow
description: 持续开发工作流。代码任务(做/加/修/改/实现/重构/bug/接入)用它:按任务大小路由→用原生步骤推进→commit/CI 机械证据门保证按流程。不依赖外部开发流程插件,不重造角色、不搞 contracts。
---

# harness-workflow — router + 证据门

## Codex 执行角色边界

网站视觉/交互/文案等前端及 UI 修复按 [canonical 用户偏好](/Users/twelve/.codex/AGENTS.md#面向公网的网站交付) 经 agent-desk 交实际 Claude Code；下文通用 Sol 路由与工具缺失降级不覆盖此例外，既有单目录串行和证据门不变。

- 顶层主控遇到代码任务时把实现、调试、构建、测试和修复交给 `sol_worker`；已被派发的 Sol 直接执行本 Skill，不再次派 Agent。
- `luna_worker` 不承担代码生命周期。需要页面复现或真实页面验证时，由主控按同一目录串行安排原 `terra_worker` 复现 → Sol 修复 → 原 Terra 验证。
- 固定角色不可用时先报告；只有 Sol 实际缺少必要执行工具且主控具备时，主控才可明确说明并接手精确限定的工具步骤，不得静默换模型或绕过权限。

**怎么"保证按流程"**:不是靠你读这段(prose 会漂),是靠 **commit 带 `Harness-Type:` + git hook/CI 查证据 artifact**。下面是推荐怎么干,执行权在机械门。

**一条底线**:开工前确认目标/范围/验收/风险;收尾报告改动/证据/未验证项/回滚。只读和可逆改动直接推进,高风险外部副作用在执行前确认。

## 公网前端交付

网站任务先读 [public-site-launch](/Users/twelve/.codex/skills/public-site-launch/SKILL.md)：把完整公开前端、已授权域名发布与真实功能接入分成里程碑。按当前里程碑收集证据，内部接入状态只进工程记录；完整前端先实现入口、表单、本地校验、步骤、选项、预览、载入、结果、返回与重试，后台未接时可直接使用示例/本地状态和演示成功态，无需另行确认内部原型；feature flags 只限制真实服务调用，不自动隐藏UI。演示证据不能冒充真实API、扣费/发送或云保存；涉及认证、资金或生产的必要检查仍适用于真实执行。

网站视觉反馈与机械全绿分开，按[视觉验收](/Users/twelve/.codex/skills/public-site-launch/references/visual-acceptance.md)绑定本次产物/实际观察。既有安全逻辑未变时仅复验受影响部分；记录done不等于整个Goal完成，不能为新任务虚标未完成Goal或绕到新chat。

## 接手任务先做

**先查记忆**(装了 claude-mem 就用):`mem-search` / query claude-mem 找"上次怎么做 / 踩过啥坑"(跨 session 对话记忆)→ `bash scripts/state.sh show`(秒级恢复;丢了 `regen`)→ 读 `.harness/change-index.jsonl`(渐进下钻)+ `docs/memory/` case·decision → 必要时 `git log --oneline -20`。仅对需要接入 harness 的目标代码项目，未接入 → 先 `bash <repo>/init.sh`；全局规则/Skill 文档维护按现有仓库与实际范围裁剪，不为此初始化新项目、在 HOME 安装 hooks 或扩建仓库。

> **记忆三层,各干各的,别当替代品**:claude-mem = 跨 session 对话 observation(插件自动记,接手时主动 query)· `.harness/records/` = 每需求沉淀(record.sh,git-tracked)· `docs/memory/` = case/decision(踩坑·架构取舍,git-tracked)。

## 沉淀(机械强制,治"每轮啥也不留")
非 trivial 任务**开工先** `id=$(bash scripts/record.sh start <type> <slug>)` 建 `.harness/records/<id>.md`,边做边填 What/Changed&Why/Tests/Decisions/Followups。**commit 必须带 `Harness-Record: <id>` 且同 commit 改了该 record.md**,否则 commit-msg/CI 拒。收尾 `bash scripts/record.sh done <id>`(校验段落非空 + append change-index)。trivial 免。

## 路由(按影响范围+可逆性,判不准往重的放)
- **trivial**(单文件/可一键 revert/不碰 schema 接口依赖)→ 直接改+测+commit。
- **bug** → 复现与定位 → 先写**会失败的测试** → 最小修复 → 回归。
- **refactor** → 用测试固化行为 → 小步改、每步全绿 → 不混功能。
- **feature/大改** → 明确需求边界与取舍 → 写计划 → 分任务实现 → 独立审查 → 定向验证 → 记录结论 → commit。

> 这些是**原生指南**，不要求加载任何外部流程插件；大改完整走，范围很小的改动按风险裁剪。

## 证据门(机械保证,commit 必须满足否则 commit/CI 拒)
改代码的 commit 必须声明 `Harness-Type: trivial|bug|feature|refactor`,并按类型带证据:
- **bug** → 同 commit 含测试文件,**或** `No-Repro: <原因>`
- **feature** → `Plan: <计划文件>`(或同 commit 含 docs/**plan*.md) **且** `Reviewed-by: codex`(过审留痕)
- **refactor** → `Behavior-Unchanged: true`(测试绿由 pre-push/CI 验)
- **trivial** → 无额外证据
回退提交(`Revert`/`Rollback`)豁免。memory 仍由 commit-msg 门要求(`Memory:` 或 case)。

## 任务板 + 串行 Agent 交接(都挂在 record.md 的 `## Tasks`)
- **任务板=record.md 的 `## Tasks`**:把需求拆成 `- [ ] N <任务>`;开发时用 Claude **TodoWrite** 做实时视图,做完一条就把 record.md 里勾成 `- [x]`(进度持久进 git,`bash scripts/record.sh tasks <id>` 看 X/N)。
- **串行交接**:每条任务标明唯一 `@owner`;所有角色使用同一个项目目录，不创建 worktree、项目副本或伴生目录；同一文件或外部状态始终只有一个 owner。
- **派发前(in)**:`bash scripts/brief.sh "<该任务>" "<文件边界>"` 生成自包含简报塞进 subagent prompt(含 state+近期 git+memory),零上下文也对齐。
- **回收(out)**:sub-agent 只回 结论+证据(改了啥/测试/决策),不回脏中间态。
- **同步(state)**:主 agent synthesize → 勾掉 record.md 对应 task + 必要时写 Decisions/decision → commit(带 `Harness-Record:<id>`,git 成共享真相)。

## 失败/降级
连续两次尝试没有新证据或实质进展时，先核原执行停止、保留有效diff/验证与复现，上报主控决定；不自动restore他人或混合WIP。代码/测试失败、有效finding不是模型调用失败，有进展的修复沿原负责人继续。
**degraded 不静默**:可选工具没装(codex/claude-mem 缺)→ 该步用原生能力完成并**明说"降级了"**,不假装。

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
