#!/usr/bin/env bash
# stale-cases.sh — list cases >90d old AND not referenced in recent commits.
# Soft reminder only: always exits 0, never blocks.
set -uo pipefail
THRESHOLD_DAYS=90
DIR="docs/memory/cases"
[ -d "$DIR" ] || exit 0
NOW=$(date +%s)

find "$DIR" -name '*.md' -type f 2>/dev/null | while read -r f; do
  mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo "$NOW")
  age_days=$(( (NOW - mtime) / 86400 ))
  if [ "$age_days" -gt "$THRESHOLD_DAYS" ]; then
    slug=$(basename "$f" .md)
    if ! git log --since="${THRESHOLD_DAYS} days ago" --grep="$slug" --oneline 2>/dev/null | grep -q .; then
      echo "陈旧 case: $f (${age_days}天) —— 复查或移到 docs/memory/archive/"
    fi
  fi
done
exit 0
