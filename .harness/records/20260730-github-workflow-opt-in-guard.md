# 20260730-github-workflow-opt-in-guard
Type: bug

## What（解决什么 + 验收）
把 GitHub Actions 从“默认不安装”升级为“默认禁止修改”：harness 不再提供 workflow 生成入口，提交和 CI 都必须看到显式授权才能接受 `.github/workflows/*` 变更。

## Tasks（拆任务 + 进度;并行 sub-agent 各认领一条,标 @owner wt=,文件不相交）
- [x] 1 先补默认拒绝、一次性授权和 CI 留痕的失败测试
- [x] 2 实现本地 hook + CI 双层机械门
- [x] 3 移除 harness 的 workflow 生成入口并更新说明
- [x] 4 跑全套测试、完成记录并提交
- [x] 5 同步到 DemoPatch 当前项目并验证

## Changed & Why（改了什么/为什么）
- 新增 `verify-github-workflows.sh`，覆盖 staged、commit-msg、CI range 三层检查。
- pre-commit 默认拒绝 `.github/workflows/*`，显式变更必须同时使用一次性环境开关和 `Workflow-Authorized:` trailer。
- 删除 harness 自带的 GitHub Actions workflow 模板及手动复制入口，避免 agent 把“可选”误解成可以顺手安装。
- 更新 init、doctor、README、SKILL 和新项目 AGENTS 模板；同步 opt-in 门到 DemoPatch 当前 Husky clone。
- 修复三处旧测试夹具漂移，使全套回归重新全绿。

## Tests（测试/验证）
- 新测试先复现 2/6 失败，再实现到 6/6 通过。
- `bash -n` 检查所有新增/变更 shell 入口。
- `bash test/run.sh`：全部测试通过。
- DemoPatch 使用隔离 `GIT_INDEX_FILE` 验证默认拒绝、显式开关放行。

## Decisions（非显然取舍）
- 采用“两把钥匙”：瞬时环境变量防误操作，commit trailer 提供永久审计；仅有其中一个都不够。
- 全局 harness 删除 workflow 生成模板，但不擅自删除业务仓库已经存在的 Docker workflow。

## Followups（遗留/下次注意）
- 已有仓库需重跑 `init.sh` 才会获得完整新门；DemoPatch 已单独同步，无需等待。

## Context（最近相关需求,自动摘自 change-index）
- {"id": "20260601-风险分级push", "type": "feature", "oneliner": "从旧 harness 挖回「风险分级 push」精华(codex 评为 5 个候选里 ROI 最高、最机械)。"}
- {"id": "20260601-state自动同步", "type": "feature", "oneliner": "治用户痛点:每轮 state.json 全 null、架构文档不同步——因为它们是 advisory(靠\"记得做\")。"}
- {"id": "20260601-harness接入完善", "type": "feature", "oneliner": "补三个真缺口(用户质疑 + codex 讨论后):brainstorming 没接、claude-mem 没接、旧项目 husky 时客户端门不激活。"}
