---
name: harness-workflow
description: One-shot scaffolder for the lite dev harness (a few markdown files + git hooks). Use when the user says "接入 harness-workflow / 起 harness-workflow / 初始化 harness / set up harness". Scaffolds a target repo and explains the conventions, then you are done — this skill has NO session lifecycle, NO orchestration, NO runtime memory checks. It runs once.
---

# harness-workflow (init)

Scaffold the lite harness into the current repo. This is a **one-shot** action.
Do NOT add session-start/session-end automation, memory-check loops, profiles, or
sub-agent orchestration — that is the old 16k-line failure mode. Enforcement lives
in git hooks (tool-agnostic), not in this skill.

## Steps

1. **Detect project type** to fill AGENTS.md command stubs:
   - `package.json` → build/test/lint from its `scripts`
   - `pyproject.toml` / `setup.py` → pytest / ruff / build backend
   - `go.mod` → `go build` / `go test ./...` / `go vet`
   - `Cargo.toml` → `cargo build` / `cargo test` / `cargo clippy`
   - else → leave `<TODO>` for the user.

2. **Run the scaffolder** (idempotent; never overwrites existing templates):

   ```bash
   bash /path/to/harness-workflow/init.sh
   ```

3. **Fill AGENTS.md** Commands section with the detected build/test/lint commands
   (edit only the `<TODO>` lines; keep the file ≤60 lines).

4. **Explain the conventions to the user** in one short message:
   - git worktree + branch per agent = isolation (this is what prevents collisions).
   - One file, one owner — only when running parallel agents, optionally create WORK.md and append a claim line. Solo work needs none of this.
   - Progress is `git log`, not a file. Session end = just commit; the commit-msg hook forces a memory case OR a visible `Memory:` trailer. There is NO file you must remember to update.

5. **Ask the user to pick the Mode** (a line in AGENTS.md, not a separate file): `loose` (commit then auto-push non-main) or `strict` (plan → confirm → commit, no push). Default `loose`.

Then stop. You are done. Future tasks (in any tool) use the scaffolded files + git hooks
directly — they do not need this skill. The harness lives in the repo, not in the tool.
