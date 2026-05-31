#!/usr/bin/env bash
# init.sh — idempotently scaffold harness-workflow into the current git repo.
# Templates are user-owned (skip if present); scripts/hooks are tool-owned (refreshed).
set -euo pipefail
HW_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$TARGET"

copy_if_absent() { # <src> <dst>
  if [ -e "$2" ]; then echo "skip (exists): $2"
  else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "create: $2"; fi
}

copy_if_absent "$HW_SRC/templates/AGENTS.md" "AGENTS.md"
copy_if_absent "$HW_SRC/templates/CLAUDE.md" "CLAUDE.md"
copy_if_absent "$HW_SRC/templates/PROJECT.md" "docs/PROJECT.md"
mkdir -p docs/memory/cases docs/memory/decisions
# Intentionally NOT created (minimalism): WORK.md (opt-in, parallel only),
# docs/memory/archive/ (lazy), .ai-mode (folded into AGENTS.md Mode line).

mkdir -p scripts .githooks
cp "$HW_SRC/scripts/verify-memory.sh" scripts/verify-memory.sh
[ -f "$HW_SRC/scripts/stale-cases.sh" ] && cp "$HW_SRC/scripts/stale-cases.sh" scripts/stale-cases.sh || true
chmod +x scripts/*.sh
for h in pre-commit commit-msg pre-push; do
  cp "$HW_SRC/githooks/$h" ".githooks/$h"; chmod +x ".githooks/$h"
done
git config core.hooksPath .githooks

echo "harness-workflow initialized in $TARGET (hooksPath -> .githooks)"
echo "Next: fill AGENTS.md commands + Mode line (loose/strict), edit docs/PROJECT.md."
echo "Progress lives in git log — there is no state file to maintain."
