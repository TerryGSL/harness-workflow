#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib

init_repo() {
  local d
  d=$(mktarget)
  ( cd "$d" && bash "$HW_ROOT/init.sh" >/dev/null 2>&1 )
  echo "$d"
}

stage_workflow() {
  local d="$1"
  mkdir -p "$d/.github/workflows"
  printf 'name: accidental\non: push\n' > "$d/.github/workflows/accidental.yml"
  ( cd "$d" && git add .github/workflows/accidental.yml )
}

precommit_blocks_workflow_by_default() {
  local d
  d=$(init_repo)
  stage_workflow "$d"
  ( cd "$d" && bash .githooks/pre-commit >/dev/null 2>&1 )
  local rc=$?
  rm -rf "$d"
  return "$rc"
}

precommit_allows_explicit_override() {
  local d
  d=$(init_repo)
  stage_workflow "$d"
  ( cd "$d" && HARNESS_ALLOW_GITHUB_WORKFLOWS=1 bash .githooks/pre-commit >/dev/null 2>&1 )
  local rc=$?
  rm -rf "$d"
  return "$rc"
}

commitmsg_blocks_missing_authorization_trailer() {
  local d msg
  d=$(init_repo)
  stage_workflow "$d"
  msg="$d/message.txt"
  printf 'ci: requested workflow\n\nHarness-Type: trivial\nMemory: none\n' > "$msg"
  ( cd "$d" && HARNESS_ALLOW_GITHUB_WORKFLOWS=1 bash scripts/verify-github-workflows.sh commit-msg "$msg" >/dev/null 2>&1 )
  local rc=$?
  rm -rf "$d"
  return "$rc"
}

commitmsg_allows_authorization_trailer() {
  local d msg
  d=$(init_repo)
  stage_workflow "$d"
  msg="$d/message.txt"
  printf 'ci: requested workflow\n\nHarness-Type: trivial\nMemory: none\nWorkflow-Authorized: explicit user request\n' > "$msg"
  ( cd "$d" && HARNESS_ALLOW_GITHUB_WORKFLOWS=1 bash scripts/verify-github-workflows.sh commit-msg "$msg" >/dev/null 2>&1 )
  local rc=$?
  rm -rf "$d"
  return "$rc"
}

ci_blocks_workflow_without_authorization() {
  local d base
  d=$(init_repo)
  ( cd "$d" && git add -A && git commit -q --no-verify -m $'chore: scaffold\n\nHarness-Type: trivial\nMemory: none' )
  base=$(cd "$d" && git rev-parse HEAD)
  stage_workflow "$d"
  ( cd "$d" && git commit -q --no-verify -m $'ci: add workflow\n\nHarness-Type: trivial\nMemory: none\nRisk-Ack: test only' )
  ( cd "$d" && bash scripts/ci-gate.sh "$base" HEAD >/dev/null 2>&1 )
  local rc=$?
  rm -rf "$d"
  return "$rc"
}

ci_allows_explicitly_authorized_workflow() {
  local d base
  d=$(init_repo)
  ( cd "$d" && git add -A && git commit -q --no-verify -m $'chore: scaffold\n\nHarness-Type: trivial\nMemory: none' )
  base=$(cd "$d" && git rev-parse HEAD)
  stage_workflow "$d"
  ( cd "$d" && git commit -q --no-verify -m $'ci: add requested workflow\n\nHarness-Type: trivial\nMemory: none\nRisk-Ack: test only\nWorkflow-Authorized: explicit user request' )
  ( cd "$d" && bash scripts/ci-gate.sh "$base" HEAD >/dev/null 2>&1 )
  local rc=$?
  rm -rf "$d"
  return "$rc"
}

refute "pre-commit 默认拒绝 GitHub workflow 变更" precommit_blocks_workflow_by_default
assert "pre-commit 仅在显式一次性开关下放行" precommit_allows_explicit_override
refute "commit-msg 拒绝缺少 Workflow-Authorized 留痕" commitmsg_blocks_missing_authorization_trailer
assert "commit-msg 接受显式 Workflow-Authorized 留痕" commitmsg_allows_authorization_trailer
refute "ci-gate 拒绝无授权留痕的 workflow commit" ci_blocks_workflow_without_authorization
assert "ci-gate 放行带 Workflow-Authorized 的 workflow commit" ci_allows_explicitly_authorized_workflow
finish
