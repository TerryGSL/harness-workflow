# 20260621-stop-auto-install-cloud-ci
Type: feature

## What（解决什么 + 验收）
用户发现接入 harness 的产品仓库(aitoonstudio 656 runs / aicustomsong)被 GitHub Actions
烧光额度。两大来源:① harness 自己 init.sh 自动装的 `harness-gate.yml`(on: push/PR 无分支过滤
→ 每次 push 都跑);② ShipAny 模版自带的 `docker-build.yaml`(on:push main 每次构建镜像推 ghcr)。
用户决定:单人开发不需要云端 gate,本地 hook 已够。
验收:① 新跑 init.sh 默认不装 harness-gate.yml(test-init 验);② project-init 新站不带 docker CI;
③ doctor 不再把"没装云端 gate"当缺项报警;④ README/文案不再宣称 CI 是必备不变量。

## Tasks
- [x] 1 init.sh: 删自动 copy harness-gate 那行,改成可选注释 + 改结尾文案
- [x] 2 doctor.sh: "缺 gate 就 warn" → info(可选,不计缺项)
- [x] 3 test-init.sh: 预期文件移除 harness-gate.yml + 加进"init 不该装"列表
- [x] 4 README.md: "CI 不可绕不变量" → "本地 hook 为主,云端 gate 可选默认不装"
- [x] 5 模版 workflow-harness-gate.yml: 触发收窄到 PR + push main(谁要装也不烧额度)
- [x] 6 project-init/init-repo.sh: 克隆后 rm docker-build.yaml + SKILL.md 记一句

## Changed & Why（改了什么/为什么）
- harness-workflow 仓库:init.sh / scripts/doctor.sh / test/test-init.sh / README.md /
  templates/workflow-harness-gate.yml —— 把云端 CI gate 从"自动装的必备层"降级为"可选兜底"。
  理由:`on: push:` 无过滤让每个分支每次 push 都跑 Actions,单人开发净是额度浪费;本地 git hook
  已执行全部红线+证据门,云端层的唯一增量价值(绕不过 --no-verify/GUI/裸 clone)对单人场景不值额度。
- 全局 skill project-init/scripts/init-repo.sh + SKILL.md —— 新站脚手架克隆 ShipAny 模版后
  删 `.github/workflows/docker-build.yaml`(空了连目录一起删,非空保留)。理由:该 workflow 每次
  push main 构建 Docker 镜像推 ghcr,新站默认 Vercel/CF 部署根本用不到,纯烧额度。

## Tests（测试/验证）
- bash -n 全部脚本过。
- test/test-init.sh → 8/0(含新断言:init 不装 harness-gate.yml)。
- test/test-doctor.sh → 3/0(新增"两层全无→fail"用例)。
- grep 复查:剩余 harness-gate 引用都是"可选/cp 指令",无强依赖。
- 全套 run.sh 另有 3 个失败(test-ci-gate/record/state)——**stash 后干净 HEAD 上一样失败**,
  是沙箱 git 权限环境问题(temp 仓 git init/commit 受限),非本次引入。
- 已对两个受害仓库(aitoonstudio/aicustomsong)删除存量 workflow 文件止血(对话内,API 删除)。

## Codex 复审补的(P1/P2 全收)
- P1 doctor: 新增 protected 标志,本地 hook 未激活 + 无云端 gate(+无 husky 接入)→ bad(原来可能误报"健康")。
- P1 事实源同步: templates/AGENTS.md、templates/WORKFLOW.md、根 SKILL.md 把"git hooks + CI 强制"
  改为"本地 hook 强制;CI 可选兜底默认不装"——否则新项目拿到的事实源和 init/doctor 新默认矛盾。
- P2 cp 命令: README/init.sh/doctor 提示统一加 `mkdir -p .github/workflows`(否则目录不存在 cp 失败)。
- P2 project-init "最快上手"手动路径补 `rm -f docker-build.yaml`(否则照抄会把 docker CI 推上去)。
- 加固: init-repo.sh 删除同时覆盖 .yml 变体;模版加 concurrency cancel-in-progress 再省额度。

## Decisions（非显然取舍）
- 模版文件 `templates/workflow-harness-gate.yml` 保留不删 —— 降级为 opt-in 而非移除能力,
  多人/PR 流场景仍可一行 cp 装回;同时把触发收窄到 PR+main,避免"装回来又烧额度"。
- docker CI 在 project-init 脚手架脚本里删(单一控制点),不去改 ShipAny 付费模版本体 ——
  改 vendor 模版会被未来 git fetch template 覆盖且不易追溯;脚手架删是幂等、自文档、用户掌控的。
- 代价已对用户讲明:去掉云端 gate 后 harness 失去"绕不过"属性,只剩本地 hook(--no-verify/GUI 能绕)。

## Followups（遗留/下次注意）
- 存量受害仓库已止血;若以后对老项目重跑 init.sh 不会再装 gate(已默认不装)。
- 若将来真要多人协作某仓库,记得手动 cp 那个(已收窄触发的)模版回去。

## Context（最近相关需求,自动摘自 change-index）
- {"id": "20260601-风险分级push", "type": "feature", "oneliner": "从旧 harness 挖回「风险分级 push」精华(codex 评为 5 个候选里 ROI 最高、最机械)。"}
- {"id": "20260601-state自动同步", "type": "feature", "oneliner": "治用户痛点:每轮 state.json 全 null、架构文档不同步——因为它们是 advisory(靠\"记得做\")。"}
- {"id": "20260601-harness接入完善", "type": "feature", "oneliner": "补三个真缺口(用户质疑 + codex 讨论后):brainstorming 没接、claude-mem 没接、旧项目 husky 时客户端门不激活。"}
