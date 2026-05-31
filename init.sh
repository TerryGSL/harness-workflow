#!/usr/bin/env bash
# init.sh — idempotently scaffold harness-workflow into the current git repo.
# Templates are user-owned (skip if present); scripts/hooks/CI are tool-owned (refreshed).
set -euo pipefail
HW_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$TARGET"

copy_if_absent() { # <src> <dst>
  if [ -e "$2" ]; then echo "skip (exists): $2"
  else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "create: $2"; fi
}

# --- user-owned templates (never overwrite) ---
copy_if_absent "$HW_SRC/templates/AGENTS.md"   "AGENTS.md"
copy_if_absent "$HW_SRC/templates/CLAUDE.md"   "CLAUDE.md"
copy_if_absent "$HW_SRC/templates/PROJECT.md"  "docs/PROJECT.md"
copy_if_absent "$HW_SRC/templates/aider.conf.yml"  ".aider.conf.yml"
copy_if_absent "$HW_SRC/templates/cursor-harness.mdc" ".cursor/rules/harness.mdc"
copy_if_absent "$HW_SRC/templates/workflow-harness-gate.yml" ".github/workflows/harness-gate.yml"
mkdir -p docs/memory/cases docs/memory/decisions
# Intentionally NOT created (minimalism): WORK.md (opt-in, parallel only),
# docs/memory/archive/ (lazy), .ai-mode (folded into AGENTS.md Mode line).

# --- tool-owned scripts + hooks (refreshed each init) ---
mkdir -p scripts .githooks
for s in gate-lib.sh verify-memory.sh ci-gate.sh stale-cases.sh memory-stats.sh; do
  [ -f "$HW_SRC/scripts/$s" ] && cp "$HW_SRC/scripts/$s" "scripts/$s" || true
done
chmod +x scripts/*.sh
for h in pre-commit commit-msg pre-push; do
  cp "$HW_SRC/githooks/$h" ".githooks/$h"; chmod +x ".githooks/$h"
done

# --- wire hooks without clobbering an existing hook manager ---
existing=$(git config --local --get core.hooksPath 2>/dev/null || true)
if [ -n "$existing" ] && [ "$existing" != ".githooks" ]; then
  echo "⚠ core.hooksPath is already '$existing' — NOT overwriting."
  echo "  Your existing hook manager stays. Wire ours manually if you want both:"
  echo "    call .githooks/{pre-commit,commit-msg,pre-push} from your manager,"
  echo "    or run: git config core.hooksPath .githooks   (replaces the other)"
elif [ -d .husky ] || [ -f lefthook.yml ] || [ -f .pre-commit-config.yaml ]; then
  echo "⚠ detected an existing hook manager (husky/lefthook/pre-commit)."
  echo "  NOT setting core.hooksPath. To use ours instead: git config core.hooksPath .githooks"
else
  git config core.hooksPath .githooks
  echo "set core.hooksPath -> .githooks"
fi

cat <<'EOF'

harness-workflow initialized.
  • Local hooks are active for THIS clone only (core.hooksPath is local git config,
    it does NOT travel on clone — each clone reruns init.sh or sets core.hooksPath).
  • The real, unbypassable invariant is CI: .github/workflows/harness-gate.yml.
    COMMIT AND PUSH the scaffold so CI is live for every tool/clone/PR:
        git add -A && git commit -m "chore: adopt harness-workflow

Memory: none" && git push
  • Progress lives in git log — there is no state file to maintain.
  • Next: fill AGENTS.md commands + Mode line (loose/strict), edit docs/PROJECT.md.
EOF
