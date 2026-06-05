<!-- doc-status: curated · owner: human · 触发: 踩坑新增时手写 -->
# codex exec 因 MCP OAuth 过期卡死 → 用 `-c mcp_servers={}` 禁用

Type: case / 编码踩坑
Date: 2026-06-01
Pattern-Key: codex-exec-disable-mcp

## 现象
本机非交互调用 `codex exec` 时长时间卡死(可能 20+ 分钟):
- 进程活着但 CPU 时间几乎为 0
- output 长时间 0 字节
- 像挂死,但实际是卡在 MCP transport 握手上

## 根因
`~/.codex/config.toml` 里配了需要 OAuth 的 MCP server(如 Notion、Linear)。
codex 启动时会去连这些 MCP server,**token 过期时卡在 transport 握手**,迟迟不进入主任务。

错误日志特征:
```
rmcp::transport::worker: worker quit with fatal: Transport channel closed,
when AuthRequired(...invalid_token...)
```

## 修复
所有**非交互**的 `codex exec` 调用都加一句禁用 MCP server:

```bash
codex exec -c 'mcp_servers={}' "..."
```

非交互场景本来就不需要 MCP server,禁用后不再尝试握手,直接进主任务。

## 适用范围
- 脚本里、CI 里、harness 审稿门里所有 headless 的 `codex exec`。
- 交互式 `codex`(人坐在前面、确实要用 MCP 工具)不受此约束。
