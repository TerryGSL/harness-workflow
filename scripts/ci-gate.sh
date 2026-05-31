#!/usr/bin/env bash
# ci-gate.sh [BASE] [HEAD] — server-side invariant (the real, unbypassable layer).
# Verifies, for every commit in the range, that code-touching commits carry a memory
# record (case/decision file OR a Memory: trailer); that no secret-like files are
# tracked at HEAD; and that the hook files still exist at HEAD (anti self-disable).
# Exits non-zero on any violation. Reuses gate-lib.sh so rules match the client hook.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/gate-lib.sh"

BASE="${1:-}"; HEAD="${2:-HEAD}"
if [ -n "$BASE" ] && git rev-parse -q --verify "${BASE}^{commit}" >/dev/null 2>&1; then
  range="${BASE}..${HEAD}"
else
  range="$(git rev-parse "$HEAD")^!"   # first push / no base -> just the tip commit
fi

fail=0

# 1. Hook files must still exist at HEAD (a commit cannot quietly remove the gate).
for f in .githooks/pre-commit .githooks/commit-msg .githooks/pre-push scripts/verify-memory.sh scripts/gate-lib.sh; do
  git cat-file -e "${HEAD}:$f" 2>/dev/null || { echo "✗ ci-gate: required file missing at HEAD: $f"; fail=1; }
done

# 2. Per-commit memory rule.
for c in $(git rev-list "$range" 2>/dev/null); do
  files=$(git diff-tree --no-commit-id --name-only -r "$c" 2>/dev/null || true)
  sig=$(printf '%s\n' "$files" | grep -E "$SIGNIFICANT_RE" || true)
  [ -z "$sig" ] && continue
  mem=$(printf '%s\n' "$files" | grep -E "$MEMORY_FILE_RE" || true)
  [ -n "$mem" ] && continue
  if git log -1 --format=%B "$c" | grep -qiE "$MEMORY_TRAILER_RE"; then continue; fi
  echo "✗ ci-gate: commit ${c:0:8} touches code but records no memory (no case/decision, no 'Memory:' trailer)"
  fail=1
done

# 3. No secret-like files tracked at HEAD.
secrets=$(git ls-tree -r --name-only "$HEAD" 2>/dev/null | grep -E "$SECRET_RE" || true)
if [ -n "$secrets" ]; then
  echo "✗ ci-gate: secret-like files are tracked:"; printf '%s\n' "$secrets" | sed 's/^/    /'
  fail=1
fi

[ "$fail" -eq 0 ] && echo "ci-gate: OK"
exit "$fail"
