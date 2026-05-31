# harness-workflow

精简、工具无关的开发 harness：**几个 markdown 文件 + git hooks + CI + 一个流程层**。
红线由 git hooks 强制（所以对 Claude、Codex、Cursor、Aider 或人——任何会 commit 的东西都生效）。
零运行时依赖。唯一的跨工具不变量就是 git-tracked 的 markdown。
**没有靠自觉更新的状态文件：进度就是 `git log`，唯一强制捕获的东西（memory）由 commit hook 钉死，不靠自觉。**

这是 `harness-workflow.legacy` 的精简重写——那套 16,664 行、17 contracts、8-stage、8-agent 的系统
实测从未落地（状态文件冻死、LEARNINGS.md 只有一行、0 个 feature 执行 commit）。本 repo 继承名字，砍掉约 90% 的噪音，
**但保留了旧系统真正有用的流程纪律**（bug 五步 TDD、feature 轻量分阶段、失败回退）——见 `docs/WORKFLOW.md`。

## 快速开始

```bash
cd 你的项目
bash /path/to/harness-workflow/init.sh   # 幂等
# 填 AGENTS.md 命令 + Mode 行（loose/strict），编辑 docs/PROJECT.md
```

在 Claude Code 里：说"接入 harness-workflow"，init skill 会帮你做上面这些。

## 安装指挥家 skill（让 Claude 能调用）
```bash
bash install.sh            # symlink skill 进 ~/.claude/skills(名字被占用则提示)
bash install.sh --force    # 接管 harness-workflow 这个名字, 旧的备份为 .legacy
bash install.sh --name X   # 装成别名, 不动旧的
```
skill 只是"大脑"(全局)；scripts/hooks/templates 由 `init.sh` 进每个项目。两者分离是有意的：换工具/换项目时大脑通用、护栏随 repo。

## 强制是怎么生效的（两层，对各自都说实话）
1. **客户端 git hooks** —— 本地快速摩擦。在*这个 clone* 里对任何 commit 的工具生效。
   注意：`core.hooksPath` 是**本地 git config**，**不随 clone 走**，`--no-verify` / GUI 合并能绕过。
   每个 clone 要跑一次 `init.sh`（或 `git config core.hooksPath .githooks`）才激活本地 hook。
2. **CI（`.github/workflows/harness-gate.yml`）** —— 真正不可绕过的不变量。
   服务端对每次 push/PR 重新校验 memory 规则、密钥规则、hook 文件是否还在，
   不管什么工具、clone、`--no-verify`。**所以你必须 commit + push 这套脚手架**——这才让规则在哪都生效。

## 你会得到（默认）
- `AGENTS.md`（≤60 行，可检查约束 + Mode 行）· `CLAUDE.md`（3 行 stub）
- `docs/WORKFLOW.md`（干活流程：任务分级 + 各档步骤）· `docs/PROJECT.md`（指针地图）
- `docs/memory/{cases,decisions}/`
- 跨工具指针：`.aider.conf.yml` · `.cursor/rules/harness.mdc`
- git hooks：pre-commit（密钥）· commit-msg（memory 门禁，带 `Memory:` 逃生口）· pre-push（不推 main + 测试 + force-push 确认）
- CI：`.github/workflows/harness-gate.yml`（服务端，不可绕过）

可选（默认不建）：`WORK.md`（只在跑并行 agent 时）。进度就是 `git log`——没有状态文件要同步。

## 怎么做到换工具就能跑
harness 长在 repo 里，不在工具配置里：`AGENTS.md`（Codex/Cursor/Aider 原生读——也铺了
`.aider.conf.yml` 和 `.cursor/rules/harness.mdc`；Claude 经 `CLAUDE.md` stub）、hooks、CI workflow、`docs/`。
换工具 → clone，跑一次 `init.sh` 装本地 hook；CI 早就在强制红线了。Claude 的 init skill 只用于第一次脚手架。
随时 `bash scripts/doctor.sh` 自检"换工具能否仅凭本 repo 冷启动接手"。

## 非目标（防退化绊线——伸手想加这些就停）
没有 TS CLI。没有 profile。没有 17 contracts。没有 team-* agent。没有 8-stage 巨流程。
没有 knowledge scanner。没有 JSON-schema 守门。没有 session orchestrator。没有运行时 memory 守护进程。
没有状态文件（current.json/progress.md/STATE.json）。就是脚手架 + git hooks + CI + 一个轻量流程层。
想要更多，见"何时升级回重型"。

## 持续开发工作流（router + 证据门）
代码任务交给指挥家 skill（`skill/harness-workflow`）：
- **按大小路由**：trivial 直接做 / bug 走调试管线 / feature 走完整管线（脑暴→计划→分任务→codex 审→验证→记忆）/ refactor 行为保持。结构当**指南**。
- **机械证据门 = "保证按流程"**：改代码的 commit 必须带 `Harness-Type:`，hook+CI 按类型查证据——bug 要测试 / feature 要 `Plan:`+`Reviewed-by:` / refactor 要 `Behavior-Unchanged:`。不合规 commit/CI 拒。**不靠模型自觉,靠机械门**。
- **subagent 同步靠 artifacts**：`scripts/brief.sh` 给子 agent 自包含简报(state.json+git+memory)；子 agent 只回结论+证据；主 agent synthesize 后更新 state + commit。
- **state.json = 可删恢复缓存**：`scripts/state.sh show/regen` 秒级恢复，门禁绝不读它（烂了能 regen，不会重演 current.json 死法）。

## 怎么迭代本 repo（漂移测试——防止它越长越胖、越胖越没用）

这套东西最大的失败模式不是"功能不够"，是**越迭代越繁重，复杂到作者自己看不懂，
而模型在实际使用中根本不读你的流程、一路漂移，最终全靠模型自己的能力**。
所以本 repo 的迭代有一条**贡献门槛**：

> **漂移测试**：要加任何东西，先问一句——"模型完全无视它，结果还会变吗？"
> - **会**（因为它是机械强制的 git hook / CI）→ 这是**护栏**，可以加。
> - **不会**（它只是靠模型自觉读的文字 / 打印的提醒）→ 这是**提示**，会漂移。
>   提示的预算极小：默认**拒绝**，除非它是一行、高频、且你真会想念它。

定位是 **护栏，不是编排（guardrails, not choreography）**：不脚本化"模型该怎么干活"
（它会漂到自己的路子，那正是模型能力发挥处），只机械兜住少数必须成立的后果。
外部 review / 读书只产出**候选**，不产出 commit——每条先过漂移测试，默认砍。
入口文件行数由 `verify-governance.sh` 机械封顶（AGENTS≤60 / WORKFLOW≤150）当硬底线。

## 何时升级回重型
任务外包给完全无人监督的多小时 agent → 加 Spec Kit。多个真人协作者 → 加 BMAD persona。
并行 agent ≥5 → 加 amux/cwork。单人 + 1-3 agent → 这套就够。
