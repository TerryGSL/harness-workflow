#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
VE="$HW_ROOT/scripts/verify-evidence.sh"
# 在临时 repo 暂存文件 + 写 msg, 跑 verify-evidence
run_case() { local msg="$1"; shift; local d; d=$(mktarget); cd "$d" || return 2
  for f in "$@"; do mkdir -p "$(dirname "$f")"; echo x > "$f"; git add "$f"; done
  printf '%s\n' "$msg" > .git/MSG; bash "$VE" .git/MSG; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc; }

refute "改代码不声明 Harness-Type 被拒"            run_case "feat: x" src/a.ts
assert "trivial 声明即过"                          run_case $'chore\n\nHarness-Type: trivial' src/a.ts
refute "bug 无测试无 No-Repro 被拒"                run_case $'fix\n\nHarness-Type: bug' src/a.ts
assert "bug 带测试文件过"                          run_case $'fix\n\nHarness-Type: bug' src/a.ts src/a.test.ts
assert "bug 带 No-Repro 过"                        run_case $'fix\n\nHarness-Type: bug\nNo-Repro: 线上偶发无法本地复现' src/a.ts
refute "feature 缺 Plan/Reviewed-by 被拒"          run_case $'feat\n\nHarness-Type: feature' src/a.ts
assert "feature 带 staged plan + Reviewed-by 过"   run_case $'feat\n\nHarness-Type: feature\nReviewed-by: codex' src/a.ts docs/superpowers/plans/p.md
refute "refactor 缺 Behavior-Unchanged 被拒"       run_case $'refactor\n\nHarness-Type: refactor' src/a.ts
assert "refactor 带 Behavior-Unchanged 过"         run_case $'refactor\n\nHarness-Type: refactor\nBehavior-Unchanged: true' src/a.ts
assert "非代码改动不要求证据"                       run_case "docs" README.md
assert "Revert 豁免"                               run_case 'Revert "feat: x"' src/a.ts
finish
