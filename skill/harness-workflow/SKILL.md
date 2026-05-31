---
name: harness-workflow
description: 精简开发 harness 的一次性脚手架（几个 markdown 文件 + git hooks + CI + 流程层）。当用户说"接入 harness-workflow / 起 harness-workflow / 初始化 harness / 装 harness"时使用。给目标 repo 铺好骨架、讲清约定，然后就结束——本 skill 没有 session 编排、没有 lifecycle、没有运行时 memory 检查，只跑一次。
---

# harness-workflow（初始化）

把精简 harness 铺进当前 repo。这是**一次性**动作。
**不要**加 session 开头/结尾自动化、memory 检查循环、profile、子 agent 编排——
那是旧的 16k 行失败模式。强制靠 git hooks + CI（跨工具），不靠本 skill。

## 步骤

1. **探测项目类型**，用来填 AGENTS.md 的命令占位：
   - `package.json` → 从 `scripts` 取 build/test/lint
   - `pyproject.toml` / `setup.py` → pytest / ruff / 构建后端
   - `go.mod` → `go build` / `go test ./...` / `go vet`
   - `Cargo.toml` → `cargo build` / `cargo test` / `cargo clippy`
   - 其它 → 留 `<TODO>` 给用户填。

2. **跑脚手架**（幂等；已存在的文件不覆盖）：

   ```bash
   bash /path/to/harness-workflow/init.sh
   ```

3. **填 AGENTS.md** 的命令段（只改 `<TODO>` 行，保持文件 ≤60 行）。

4. **用一句话给用户讲清约定**：
   - git worktree + 每 agent 一个分支 = 隔离（防止互相踩踏靠这个）。
   - 一文件一主人——只有跑并行 agent 时才建 WORK.md、append 一行 claim。单人不用。
   - 进度看 `git log`，不是文件。session 结尾 = 直接 commit；commit-msg hook 会强制写 memory case 或可见的 `Memory:` trailer。**没有哪个文件需要你记得去更新**。
   - 干活流程看 `docs/WORKFLOW.md`（任务分级 + bug/feature/refactor 各自步骤）。

5. **让用户选 Mode**（AGENTS.md 里的一行，不是单独文件）：`loose`（commit 后自动推非 main）或 `strict`（先列计划→确认→commit，不推）。默认 `loose`。

然后停。你做完了。以后的任务（任何工具）直接用铺好的文件 + git hooks + CI + WORKFLOW.md，
**不需要再调本 skill**。harness 长在 repo 里，不在工具里。
