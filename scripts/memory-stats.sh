#!/usr/bin/env bash
# memory-stats.sh [N] — soft visibility on the escape hatch (never blocks, exits 0).
# If a high fraction of the last N commits used `Memory: none/trivial`, nudge the user.
# This is the "keep the escape hatch but make laziness visible" mechanism.
set -uo pipefail
N="${1:-30}"
revs=$(git log -n "$N" --format=%H 2>/dev/null || true)
[ -z "$revs" ] && exit 0
none=0; cnt=0
while read -r c; do
  [ -z "$c" ] && continue
  cnt=$((cnt+1))
  git log -1 --format=%B "$c" 2>/dev/null | grep -qiE '^Memory:[[:space:]]*(none|trivial)' && none=$((none+1))
done <<EOF
$revs
EOF
[ "$cnt" -eq 0 ] && exit 0
pct=$(( none * 100 / cnt ))
if [ "$pct" -ge 80 ] && [ "$cnt" -ge 10 ]; then
  echo "ℹ memory: ${none}/${cnt} (${pct}%) of recent commits used 'Memory: none/trivial'." >&2
  echo "  If you've been fixing real bugs or making non-obvious choices, write a case/decision." >&2
fi
exit 0
