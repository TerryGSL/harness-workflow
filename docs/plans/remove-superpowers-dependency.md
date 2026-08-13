<!-- doc-status: frozen · owner: 人工 · 触发: 本计划归档 -->
# 移除 Superpowers 依赖计划

1. 把 bug、refactor、feature 路由改写为 Harness 原生步骤，不再调度外部开发流程插件。
2. 删除 `Brainstormed-by` 正则、本地证据门和 CI 门要求，保留 feature 的 `Plan` 与 `Reviewed-by`。
3. 同步 WORKFLOW 模板、README、session 初始化提示和测试。
4. 运行全部 Harness 自测与 Skill 结构验证，确认历史记录之外无活跃依赖。
