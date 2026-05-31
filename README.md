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
- cross-tool pointers: `.aider.conf.yml` · `.cursor/rules/harness.mdc`
- git hooks: pre-commit (secrets) · commit-msg (memory gate w/ `Memory:` escape) · pre-push (no-main + tests + soft reminders)
- CI: `.github/workflows/harness-gate.yml` (server-side, unbypassable)

Opt-in (not created by default): `WORK.md` (only when running parallel agents). Progress
is `git log` — there is no state file to keep in sync.

## How enforcement actually works (two layers, honest about each)
1. **Client git hooks** — fast local friction. They fire for any tool that commits in
   *this clone*. Caveat: `core.hooksPath` is **local git config**, so it does NOT travel
   on clone, and `--no-verify` / GUI merges bypass it. Each clone must run `init.sh`
   (or `git config core.hooksPath .githooks`) once to activate local hooks.
2. **CI (`.github/workflows/harness-gate.yml`)** — the real, unbypassable invariant.
   It re-checks the memory rule, secret rule, and that hook files still exist, on the
   server, for every push/PR, regardless of tool, clone, or `--no-verify`. **This is why
   you must commit + push the scaffold** — that's what makes the rules real everywhere.

## How it stays in sync across tools
The harness lives in the repo, not in any tool's config: `AGENTS.md` (Codex/Cursor/Aider
read it natively — `.aider.conf.yml` and `.cursor/rules/harness.mdc` are scaffolded too;
Claude via the `CLAUDE.md` stub), the hooks, the CI workflow, and `docs/`. Switch tools →
clone, run `init.sh` once for local hooks; CI already enforces the red lines. The Claude
init skill is only for the first scaffold.

## NON-GOALS (tripwire — if you reach for these, stop)
No TS CLI. No profiles. No 17 contracts. No team-* agents. No 8-stage flow.
No knowledge scanner. No JSON-schema gates. No session orchestrator. No runtime
memory daemon. No state file (current.json/progress.md/STATE.json). Just scaffold +
git hooks + a tiny CI gate. When you want more, see "When to scale up".

## When to scale up
Outsource to unsupervised multi-hour agents → add Spec Kit. Multiple human collaborators
→ add BMAD personas. ≥5 parallel agents → add amux/cwork. Solo + 1-3 agents → this is enough.
