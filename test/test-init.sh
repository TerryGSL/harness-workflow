#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
INIT="$HW_ROOT/init.sh"

run_init() { local d="$1"; ( cd "$d" && bash "$INIT" >/dev/null 2>&1 ); }

scaffolds_files() {
  local d; d=$(mktarget); run_init "$d"
  local ok=0
  for f in AGENTS.md CLAUDE.md docs/PROJECT.md docs/WORKFLOW.md .harness/state.json \
           .aider.conf.yml .cursor/rules/harness.mdc \
           docs/memory/summary.md .harness/change-index.jsonl \
           scripts/gate-lib.sh scripts/verify-memory.sh scripts/verify-evidence.sh scripts/verify-governance.sh \
           scripts/ci-gate.sh scripts/doctor.sh scripts/state.sh scripts/record.sh scripts/verify-github-workflows.sh \
           .githooks/pre-commit .githooks/commit-msg .githooks/pre-push; do
    [ -e "$d/$f" ] || { echo "missing $f" >&2; ok=1; }
  done
  [ -d "$d/docs/memory/cases" ] && [ -d "$d/docs/memory/decisions" ] && [ -d "$d/.harness/records" ] || ok=1
  rm -rf "$d"; return $ok
}
omits_optional_files() {  # minimalism: init must NOT create these
  local d; d=$(mktarget); run_init "$d"
  local ok=0
  [ -e "$d/WORK.md" ] && ok=1
  [ -e "$d/.ai-mode" ] && ok=1
  [ -d "$d/docs/memory/archive" ] && ok=1
  [ -d "$d/.github" ] && ok=1  # harness 不能创建任何 GitHub Actions 入口
  rm -rf "$d"; return $ok
}
sets_hookspath() {
  local d; d=$(mktarget); run_init "$d"
  local v; v=$(cd "$d" && git config core.hooksPath)
  rm -rf "$d"; [ "$v" = ".githooks" ]
}
does_not_clobber_existing_hookspath() {
  local d; d=$(mktarget); ( cd "$d" && git config core.hooksPath .myhooks )
  run_init "$d"
  local v; v=$(cd "$d" && git config core.hooksPath)
  rm -rf "$d"; [ "$v" = ".myhooks" ]   # ours must NOT overwrite
}
is_idempotent() {  # user edits to AGENTS.md survive re-init
  local d; d=$(mktarget); run_init "$d"
  echo "MY EDIT" >> "$d/AGENTS.md"; run_init "$d"
  grep -q "MY EDIT" "$d/AGENTS.md"; local rc=$?
  rm -rf "$d"; return $rc
}

husky_integration() {  # 真实 husky:hooksPath 已指 .husky/_ —— init 仍须自动接红线(不被 hooksPath 判断挡)
  local d; d=$(mktarget)
  ( cd "$d" && mkdir -p .husky/_ && git config core.hooksPath .husky/_ \
    && printf '#!/usr/bin/env sh\nnpx lint-staged\n' > .husky/pre-commit )
  run_init "$d"
  local ok=0
  grep -q 'harness-workflow' "$d/.husky/commit-msg" 2>/dev/null || { echo "commit-msg 未接入" >&2; ok=1; }
  grep -q 'harness-workflow' "$d/.husky/pre-commit" 2>/dev/null || { echo "pre-commit 未接入" >&2; ok=1; }
  grep -q 'lint-staged' "$d/.husky/pre-commit" 2>/dev/null || { echo "覆盖了用户已有内容" >&2; ok=1; }  # 不覆盖
  [ "$(cd "$d" && git config core.hooksPath)" = ".husky/_" ] || { echo "抢了/改了 hooksPath" >&2; ok=1; }
  rm -rf "$d"; return $ok
}
husky_idempotent() {  # 重复 init 不重复 append
  local d; d=$(mktarget); ( cd "$d" && mkdir -p .husky )
  run_init "$d"; run_init "$d"
  local n; n=$(grep -c 'harness-workflow（勿删' "$d/.husky/commit-msg" 2>/dev/null || echo 9)
  rm -rf "$d"; [ "$n" = 1 ]
}
husky_not_hijacked() {  # 有 .husky 但 hooksPath 指别处(.myhooks) → 不接(git 跑别处,接了无效)
  local d; d=$(mktarget)
  ( cd "$d" && mkdir -p .husky && git config core.hooksPath .myhooks )
  run_init "$d"
  ! grep -q 'harness-workflow' "$d/.husky/commit-msg" 2>/dev/null; local rc=$?
  rm -rf "$d"; return $rc
}
assert "init scaffolds all files + memory dirs" scaffolds_files
assert "init omits optional files and all GitHub Actions paths" omits_optional_files
assert "init sets core.hooksPath=.githooks on clean repo" sets_hookspath
assert "init does NOT clobber an existing core.hooksPath" does_not_clobber_existing_hookspath
assert "init is idempotent (keeps user edits)" is_idempotent
assert "init 检测 husky → 机械接入 .husky/(不覆盖/不抢 hooksPath)" husky_integration
assert "husky 接入幂等(重复 init 不重复 append)" husky_idempotent
assert "有 .husky 但 hooksPath 指别处 → 不劫持(收窄,codex 复审)" husky_not_hijacked
finish
