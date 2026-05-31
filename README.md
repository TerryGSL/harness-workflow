# harness-workflow

A lite, tool-agnostic dev harness: **a few markdown files + git hooks**. Red lines are
enforced by git hooks (so they fire for Claude, Codex, Cursor, Aider, or a human —
anything that commits). Zero runtime dependency. The only cross-tool invariant is
git-tracked markdown. **No discipline-dependent state file: progress is `git log`,
and the one thing we force-capture (memory) is enforced by a commit hook, not goodwill.**

This is the lite rewrite of `harness-workflow.legacy` — the 16,664-line, 17-contract,
8-stage, 8-agent system that, measured in practice, never landed (state files frozen,
LEARNINGS.md one line, zero feature-execution commits). This repo keeps the name and
drops ~90% of the noise.

## Quickstart

```bash
cd your-project
bash /path/to/harness-workflow/init.sh   # idempotent
# fill AGENTS.md commands + Mode line (loose/strict), edit docs/PROJECT.md
```

In Claude Code: say "接入 harness-workflow" and the init skill does the above.

## What you get (default)
- `AGENTS.md` (≤60 lines, testable constraints + Mode line) · `CLAUDE.md` (3-line stub)
- `docs/PROJECT.md` (pointer map) · `docs/memory/{cases,decisions}/`
- git hooks: pre-commit (secrets) · commit-msg (memory gate w/ `Memory:` escape) · pre-push (no-main + tests + stale)

Opt-in (not created by default): `WORK.md` (only when running parallel agents). Progress
is `git log` — there is no state file to keep in sync.

## How it stays in sync across tools
The harness lives in the repo, not in any tool's config. Clone the repo and you inherit:
AGENTS.md (Codex/Cursor/Aider read it natively; Claude via the CLAUDE.md stub), the git
hooks (via `core.hooksPath`, fire for every tool that commits), and docs/. Switch tools →
nothing to reinstall. The Claude init skill is only for the first scaffold.

## NON-GOALS (tripwire — if you reach for these, stop)
No TS CLI. No profiles. No 17 contracts. No team-* agents. No 8-stage flow.
No knowledge scanner. No JSON-schema gates. No session orchestrator. No runtime
memory daemon. No state file (current.json/progress.md/STATE.json). Scaffold + git
hooks only. When you want more, see "When to scale up".

## When to scale up
Outsource to unsupervised multi-hour agents → add Spec Kit. Multiple human collaborators
→ add BMAD personas. ≥5 parallel agents → add amux/cwork. Solo + 1-3 agents → this is enough.
