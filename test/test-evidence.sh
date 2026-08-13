#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
VE="$HW_ROOT/scripts/verify-evidence.sh"
# 在临时 repo 暂存文件 + 写 msg, 跑 verify-evidence
run_case() { local msg="$1"; shift; local d; d=$(mktarget); cd "$d" || return 2
  for f in "$@"; do mkdir -p "$(dirname "$f")"; echo x > "$f"; git add "$f"; done
  printf '%s\n' "$msg" > .git/MSG; bash "$VE" .git/MSG; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc; }

REC=".harness/records/20260601-x.md"
refute "改代码不声明 Harness-Type 被拒"            run_case "feat: x" src/a.ts
assert "trivial 声明即过(免 record)"               run_case $'chore\n\nHarness-Type: trivial' src/a.ts
# 沉淀门
refute "feature 缺 Harness-Record 被拒"            run_case $'feat\n\nHarness-Type: feature\nReviewed-by: codex' src/a.ts docs/plans/p.md
refute "feature 有 Record 但没改 record.md 被拒"   run_case $'feat\n\nHarness-Type: feature\nHarness-Record: 20260601-x\nReviewed-by: codex' src/a.ts docs/plans/p.md
# 全齐(带 record.md + 同 commit)
assert "bug 全齐过(record+测试)"                    run_case $'fix\n\nHarness-Type: bug\nHarness-Record: 20260601-x' src/a.ts src/a.test.ts "$REC"
assert "bug 全齐过(record+No-Repro)"                run_case $'fix\n\nHarness-Type: bug\nHarness-Record: 20260601-x\nNo-Repro: 偶发' src/a.ts "$REC"
assert "feature 全齐过(record+plan+review)"          run_case $'feat\n\nHarness-Type: feature\nHarness-Record: 20260601-x\nReviewed-by: codex' src/a.ts docs/plans/p.md "$REC"
assert "refactor 全齐过(record+Behavior-Unchanged)" run_case $'refactor\n\nHarness-Type: refactor\nHarness-Record: 20260601-x\nBehavior-Unchanged: true' src/a.ts "$REC"
assert "非代码改动不要求证据"                       run_case "docs" README.md
assert "Revert 豁免"                               run_case 'Revert "feat: x"' src/a.ts
finish
