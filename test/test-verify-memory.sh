#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
VM="$HW_ROOT/scripts/verify-memory.sh"

# helper: in a fresh repo, stage given files, write msg, run verify-memory
run_case() { # <msgfile-content> <files-to-stage...> ; returns verify-memory exit
  local msg="$1"; shift
  local d; d=$(mktarget); cd "$d" || return 2
  for f in "$@"; do mkdir -p "$(dirname "$f")"; echo x > "$f"; git add "$f"; done
  printf '%s\n' "$msg" > .git/COMMIT_MSG
  bash "$VM" .git/COMMIT_MSG; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc
}

refute "src change w/o case or trailer is rejected" run_case "feat: thing" src/a.ts
assert "src change WITH Memory: none trailer passes"  run_case $'feat: thing\n\nMemory: none' src/a.ts
assert "src change WITH staged case passes"           run_case "fix: bug" src/a.ts docs/memory/cases/2026-05-31-x.md
assert "docs-only change passes silently"             run_case "docs: tweak" README.md
assert "schema change WITH trailer passes"            run_case $'feat\n\nMemory: trivial' db/schema.sql
# broadened significant-path coverage (codex #4)
refute "app/ change w/o memory is rejected"           run_case "feat" app/x.tsx
refute "lib/ change w/o memory is rejected"           run_case "feat" lib/y.go
refute "root *.py change w/o memory is rejected"      run_case "feat" main.py
refute "package.json change w/o memory is rejected"   run_case "chore" package.json
# revert/rollback 豁免 (codex #11 / round-4 ⑩)
assert "Revert 提交豁免 memory 门禁"                   run_case 'Revert "feat: x"' src/a.ts
assert "Rollback: trailer 豁免"                        run_case $'chore\n\nRollback: bad deploy' src/a.ts
finish
