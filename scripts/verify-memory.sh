#!/usr/bin/env bash
# verify-memory.sh <commit-msg-file>
# Memory gate (client-side, commit-msg hook). If staged changes touch significant
# paths, require either a staged docs/memory/{cases,decisions} file OR a visible
# `Memory:` trailer. Shares patterns with ci-gate.sh via gate-lib.sh.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/gate-lib.sh"

MSG_FILE="${1:-}"
if [ -z "$MSG_FILE" ] || [ ! -f "$MSG_FILE" ]; then
  echo "verify-memory: missing commit message file" >&2; exit 2
fi

staged=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
[ -z "$staged" ] && exit 0

significant=$(printf '%s\n' "$staged" | grep -E "$SIGNIFICANT_RE" || true)
[ -z "$significant" ] && exit 0

mem_staged=$(printf '%s\n' "$staged" | grep -E "$MEMORY_FILE_RE" || true)
[ -n "$mem_staged" ] && exit 0

if grep -qiE "$MEMORY_TRAILER_RE" "$MSG_FILE"; then
  exit 0
fi

cat >&2 <<'EOF'
✗ memory gate: this commit touches code/schema/tests but records no memory.
  Do ONE of:
    • add docs/memory/cases/<date>-<slug>.md      (bug fix / non-trivial gotcha)
    • add docs/memory/decisions/<date>-<slug>.md  (non-obvious architecture choice)
    • add a commit-message trailer:                Memory: none   (or: trivial)
  The trailer is recorded in git history — laziness leaves a trace.
EOF
exit 1
