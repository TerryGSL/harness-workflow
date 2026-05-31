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
refute "pre-push blocks push to main" pp_blocks_main
assert "pre-push allows feature branch" pp_allows_feature
finish
