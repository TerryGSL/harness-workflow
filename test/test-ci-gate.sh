#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
INIT="$HW_ROOT/init.sh"
CI="$HW_ROOT/scripts/ci-gate.sh"

# A repo with the scaffold committed. --no-verify everywhere so we test ci-gate in
# isolation (it is the server-side layer that must catch bypassed client hooks).
init_repo() {
  local d; d=$(mktemp -d)
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t \
    && bash "$INIT" >/dev/null 2>&1 \
    && git add -A && git commit -q --no-verify -m $'chore: scaffold\n\nHarness-Type: trivial\nMemory: none' )
  echo "$d"
}
run_ci() { ( cd "$1" && bash "$CI" >/dev/null 2>&1 ); }

ci_passes_clean() {
  local d; d=$(init_repo); run_ci "$d"; local rc=$?; rm -rf "$d"; return $rc   # expect 0
}
ci_blocks_code_without_memory() {
  local d; d=$(init_repo)
  ( cd "$d" && mkdir -p src && echo x > src/a.ts && git add -A && git commit -q --no-verify -m "feat: code" )
  run_ci "$d"; local rc=$?; rm -rf "$d"; return $rc   # expect non-zero
}
ci_passes_code_with_trailer() {
  local d; d=$(init_repo)
  ( cd "$d" && mkdir -p src && echo x > src/a.ts && git add -A && git commit -q --no-verify -m $'feat: code\n\nHarness-Type: trivial\nMemory: none' )
  run_ci "$d"; local rc=$?; rm -rf "$d"; return $rc   # expect 0
}
ci_blocks_no_type() {
  local d; d=$(init_repo)
  ( cd "$d" && mkdir -p src && echo x > src/a.ts && git add -A && git commit -q --no-verify -m $'feat: code\n\nMemory: none' )
  run_ci "$d"; local rc=$?; rm -rf "$d"; return $rc   # expect non-zero (memory ok, 但缺 Harness-Type)
}
ci_blocks_missing_hook() {
  local d; d=$(init_repo)
  ( cd "$d" && git rm -q .githooks/commit-msg && git commit -q --no-verify -m $'chore: rm hook\n\nMemory: none' )
  run_ci "$d"; local rc=$?; rm -rf "$d"; return $rc   # expect non-zero (hook gone at HEAD)
}
ci_blocks_tracked_secret() {
  local d; d=$(init_repo)
  ( cd "$d" && echo k > id_rsa && git add id_rsa && git commit -q --no-verify -m $'chore\n\nMemory: none' )
  run_ci "$d"; local rc=$?; rm -rf "$d"; return $rc   # expect non-zero
}

ci_blocks_feature_no_record() {
  local d; d=$(init_repo)
  ( cd "$d" && mkdir -p src && echo x > src/a.ts && git add -A && git commit -q --no-verify -m $'feat\n\nHarness-Type: feature\nMemory: none' )
  run_ci "$d"; local rc=$?; rm -rf "$d"; return $rc   # 非0(缺 Harness-Record / record.md)
}
refute "ci-gate 拦 feature 无沉淀 record" ci_blocks_feature_no_record
assert "ci-gate passes a clean scaffold commit" ci_passes_clean
refute "ci-gate blocks bypassed code commit w/o memory" ci_blocks_code_without_memory
assert "ci-gate passes code commit with Harness-Type + Memory" ci_passes_code_with_trailer
refute "ci-gate 拦绕过的无 Harness-Type 代码提交" ci_blocks_no_type
refute "ci-gate blocks a commit that removed a hook file" ci_blocks_missing_hook
refute "ci-gate blocks a tracked secret file" ci_blocks_tracked_secret
finish
