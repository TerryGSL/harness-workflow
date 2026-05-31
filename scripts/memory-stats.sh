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
  echo "ℹ memory：最近 ${cnt} 个 commit 里有 ${none} 个（${pct}%）用了 'Memory: none/trivial'。" >&2
  echo "  如果你在修真 bug 或做非显然取舍，写个 case/decision 吧。" >&2
fi
exit 0
