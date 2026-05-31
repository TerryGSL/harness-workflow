#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib

# pre-commit: block secrets
pc_blocks_env() {
  local d; d=$(mktarget); cd "$d" || return 2
  cp "$HW_ROOT/githooks/pre-commit" .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
  echo "SECRET=1" > .env; git add .env
  git commit -q -m "oops" ; local rc=$?     # commit should be REJECTED
  cd - >/dev/null; rm -rf "$d"; return $rc
}
# pre-commit: allow normal file
pc_allows_normal() {
  local d; d=$(mktarget); cd "$d" || return 2
  cp "$HW_ROOT/githooks/pre-commit" .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
  echo "hi" > README.md; git add README.md
  git commit -q -m "docs" ; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc
}
# pre-commit: block private key (broadened secret pattern, codex #14) — needs gate-lib
pc_blocks_private_key() {
  local d; d=$(mktarget); cd "$d" || return 2
  mkdir -p scripts; cp "$HW_ROOT/scripts/gate-lib.sh" scripts/gate-lib.sh
  cp "$HW_ROOT/githooks/pre-commit" .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
  echo "key" > id_rsa; git add id_rsa
  git commit -q -m "oops" ; local rc=$?     # should be REJECTED
  cd - >/dev/null; rm -rf "$d"; return $rc
}
# pre-push: block main
pp_blocks_main() {
  local d; d=$(mktarget); cd "$d" || return 2
  printf 'refs/heads/x %s refs/heads/main %s\n' 0000 0000 | bash "$HW_ROOT/githooks/pre-push" origin file://x; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc
}
# pre-push: allow feature branch (no package.json -> tests skipped)
pp_allows_feature() {
  local d; d=$(mktarget); cd "$d" || return 2
  printf 'refs/heads/x %s refs/heads/feat/y %s\n' 0000 0000 | bash "$HW_ROOT/githooks/pre-push" origin file://x; local rc=$?
  cd - >/dev/null; rm -rf "$d"; return $rc
}

refute "pre-commit blocks .env" pc_blocks_env
assert "pre-commit allows README" pc_allows_normal
refute "pre-commit blocks private key (id_rsa)" pc_blocks_private_key
refute "pre-push blocks push to main" pp_blocks_main
assert "pre-push allows feature branch" pp_allows_feature

# force-push 检测：真实非快进 → 触发警告(HARNESS_CONFIRM=1 放行但留警告)
pp_detects_forcepush() {
  local d; d=$(mktarget); cd "$d" || return 2
  echo a > f; git add -A; git commit -q -m c1; local base; base=$(git rev-parse HEAD)
  echo b >> f; git commit -q -aim c2; local tip; tip=$(git rev-parse HEAD)
  git checkout -q -b other "$base"; echo z > g; git add -A; git commit -q -m c3; local other; other=$(git rev-parse HEAD)
  local out; out=$(printf 'refs/heads/x %s refs/heads/feat %s\n' "$tip" "$other" | HARNESS_CONFIRM=1 bash "$HW_ROOT/githooks/pre-push" origin url 2>&1)
  cd - >/dev/null; rm -rf "$d"
  printf '%s' "$out" | grep -q 'force-push'
}
assert "pre-push 检测到 force-push 并警告" pp_detects_forcepush
finish
