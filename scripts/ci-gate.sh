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
  git cat-file -e "${HEAD}:$f" 2>/dev/null || { echo "✗ ci-gate：HEAD 缺少必需文件：$f"; fail=1; }
done

# 2. Per-commit: memory 门 + 证据门(同一遍, 不早退以免漏检)。
for c in $(git rev-list "$range" 2>/dev/null); do
  files=$(git diff-tree --no-commit-id --name-only -r "$c" 2>/dev/null || true)
  sig=$(printf '%s\n' "$files" | grep -E "$SIGNIFICANT_RE" || true)
  [ -z "$sig" ] && continue
  msg=$(git log -1 --format=%B "$c")
  printf '%s\n' "$msg" | head -1 | grep -qE "$MEMORY_EXEMPT_RE" && continue
  printf '%s\n' "$msg" | grep -qiE '^(Revert|Rollback):' && continue
  # memory 门
  mem=$(printf '%s\n' "$files" | grep -E "$MEMORY_FILE_RE" || true)
  if [ -z "$mem" ] && ! printf '%s\n' "$msg" | grep -qiE "$MEMORY_TRAILER_RE"; then
    echo "✗ ci-gate：commit ${c:0:8} 动了代码但没记 memory（无 case/decision，也无 'Memory:' trailer）"; fail=1
  fi
  # 证据门
  ctype=$(printf '%s\n' "$msg" | grep -iE "$HARNESS_TYPE_RE" | grep -oiE '(trivial|bug|feature|refactor)' | head -1 | tr 'A-Z' 'a-z')
  if [ -z "$ctype" ]; then
    echo "✗ ci-gate：commit ${c:0:8} 改了代码但未声明 Harness-Type"; fail=1
  else case "$ctype" in
    bug)
      if printf '%s\n' "$files" | grep -qE "$TEST_FILE_RE"; then :
      elif printf '%s\n' "$msg" | grep -qiE '^No-Repro:[[:space:]]*[^[:space:]]'; then :
      else echo "✗ ci-gate：bug commit ${c:0:8} 无测试/无 No-Repro"; fail=1; fi ;;
    feature)
      printf '%s\n' "$msg" | grep -qiE '^Reviewed-by:[[:space:]]*[^[:space:]]' || { echo "✗ ci-gate：feature commit ${c:0:8} 缺 Reviewed-by"; fail=1; } ;;
    refactor)
      printf '%s\n' "$msg" | grep -qiE '^Behavior-Unchanged:[[:space:]]*(true|yes|是)' || { echo "✗ ci-gate：refactor commit ${c:0:8} 缺 Behavior-Unchanged"; fail=1; } ;;
  esac; fi
done

# 3. No secret-like files tracked at HEAD.
secrets=$(git ls-tree -r --name-only "$HEAD" 2>/dev/null | grep -E "$SECRET_RE" || true)
if [ -n "$secrets" ]; then
  echo "✗ ci-gate：仓库里 track 了密钥类文件："; printf '%s\n' "$secrets" | sed 's/^/    /'
  fail=1
fi

# 4. 入口文件行数治理(单一规则源,与 pre-commit 同调)。CI 已 checkout,直接对工作树跑。
if [ -x "$DIR/verify-governance.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-governance.sh ) || fail=1
fi

[ "$fail" -eq 0 ] && echo "ci-gate：通过"
exit "$fail"
