# 20260813-remove-superpowers-dependency
Type: feature

## What（解决什么 + 验收）
移除 harness-workflow 对 Superpowers 的所有运行时、文档和机械证据依赖。验收为活跃技能说明、模板、初始化提示、commit-msg 门、CI 门与测试均不再引用 Superpowers，也不再要求 `Brainstormed-by:` trailer；历史记录保持不变。

## Tasks（拆任务 + 进度;并行 sub-agent 各认领一条,标 @owner wt=,文件不相交）
- [x] 1 把路由与模板改为 Harness 原生的边界→计划→实现→审查→验证流程
- [x] 2 删除 Brainstormed-by 机械门并同步测试、README 与初始化提示

## Changed & Why（改了什么/为什么）
`SKILL.md` 不再调度 Superpowers；bug/refactor/feature 都以模型原生步骤描述。`gate-lib.sh`、`verify-evidence.sh`、`ci-gate.sh` 删除 `Brainstormed-by` 正则和强制校验。模板、README、session prompt 与测试同步，避免文档说已移除但旧 hook 仍阻断提交。

## Tests（测试/验证）
逐个运行全部 `test/test-*.sh`，路由、证据门、CI 门、初始化、模板、memory、状态与治理测试全部通过；活跃规则关键字扫描仅在本记录说明中命中，执行代码与当前入口无残留。

## Decisions（非显然取舍）
- 保留历史 memory/AGENTS 中对过去 Superpowers 设计的描述，不改写既有历史；仅移除当前可执行规则和当前用户入口中的依赖。
- feature 仍保留 Plan 与 Reviewed-by 两道可验证证据，删除的是外部插件和 Brainstormed-by 仪式，不降低计划与审查要求。

## Followups（遗留/下次注意）
- 已初始化项目持有自己的 hook 副本，需要通过 harness 更新流程同步后才会移除旧 Brainstormed-by 门。

## Context（最近相关需求,自动摘自 change-index）
- {"id": "20260601-风险分级push", "type": "feature", "oneliner": "从旧 harness 挖回「风险分级 push」精华(codex 评为 5 个候选里 ROI 最高、最机械)。"}
- {"id": "20260601-state自动同步", "type": "feature", "oneliner": "治用户痛点:每轮 state.json 全 null、架构文档不同步——因为它们是 advisory(靠\"记得做\")。"}
- {"id": "20260601-harness接入完善", "type": "feature", "oneliner": "补三个真缺口(用户质疑 + codex 讨论后):brainstorming 没接、claude-mem 没接、旧项目 husky 时客户端门不激活。"}
- {"id": "20260730-github-workflow-opt-in-guard", "type": "bug", "oneliner": "把 GitHub Actions 从“默认不安装”升级为“默认禁止修改”：harness 不再提供 workflow 生成入口，提交和 CI 都必须看到显式授权才能接受 `.github/workflows/*` 变更。"}
