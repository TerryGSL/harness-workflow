#!/usr/bin/env bash
# verify-memory.sh <commit-msg-file>
# Memory gate. If staged changes touch code/schema/scripts/tests, require either
# a staged docs/memory/{cases,decisions} file OR a visible `Memory:` trailer.
set -uo pipefail

MSG_FILE="${1:-}"
if [ -z "$MSG_FILE" ] || [ ! -f "$MSG_FILE" ]; then
  echo "verify-memory: missing commit message file" >&2; exit 2
fi

staged=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
[ -z "$staged" ] && exit 0

significant=$(printf '%s\n' "$staged" | grep -E '^(src/|scripts/|tests?/)|\.(sql|prisma|graphql)$|schema|\.(test|spec)\.' || true)
[ -z "$significant" ] && exit 0

mem_staged=$(printf '%s\n' "$staged" | grep -E '^docs/memory/(cases|decisions)/.+\.md$' || true)
[ -n "$mem_staged" ] && exit 0

if grep -qiE '^Memory:[[:space:]]*[^[:space:]]+' "$MSG_FILE"; then
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
