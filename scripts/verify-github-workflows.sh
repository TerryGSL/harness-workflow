#!/usr/bin/env bash
# GitHub Actions opt-in gate.
# Harness must never create or modify .github/workflows/* as a side effect.
# Explicit workflow work requires both:
#   HARNESS_ALLOW_GITHUB_WORKFLOWS=1 (one-shot local acknowledgement)
#   Workflow-Authorized: <who/why>   (durable commit audit trail)
set -uo pipefail

MODE="${1:-staged}"
WORKFLOW_RE='^\.github/workflows/'

staged_workflows() {
  git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMRD 2>/dev/null \
    | grep -E "$WORKFLOW_RE" || true
}

require_authorization_trailer() {
  local msg_file="$1"
  grep -qiE '^Workflow-Authorized:[[:space:]]*[^[:space:]]' "$msg_file" 2>/dev/null && return 0
  echo "✗ GitHub Actions 门：workflow 变更缺少 Workflow-Authorized: <明确用户授权>。" >&2
  return 1
}

case "$MODE" in
  staged)
    files=$(staged_workflows)
    [ -z "$files" ] && exit 0
    if [ "${HARNESS_ALLOW_GITHUB_WORKFLOWS:-0}" != "1" ]; then
      echo "✗ GitHub Actions 门：harness 默认禁止新增、修改或删除 .github/workflows/*。" >&2
      printf '%s\n' "$files" | sed 's/^/    /' >&2
      echo "  只有用户明确要求该 workflow 变更时，才可一次性使用：" >&2
      echo "    HARNESS_ALLOW_GITHUB_WORKFLOWS=1 git commit ..." >&2
      echo "  且 commit 必须带：Workflow-Authorized: <明确用户授权>" >&2
      exit 1
    fi
    ;;
  commit-msg)
    files=$(staged_workflows)
    [ -z "$files" ] && exit 0
    [ "${HARNESS_ALLOW_GITHUB_WORKFLOWS:-0}" = "1" ] || {
      echo "✗ GitHub Actions 门：缺少一次性 HARNESS_ALLOW_GITHUB_WORKFLOWS=1 授权。" >&2
      exit 1
    }
    require_authorization_trailer "${2:-}" || exit 1
    ;;
  range)
    base="${2:-}"
    head="${3:-HEAD}"
    if [ -n "$base" ] && git rev-parse -q --verify "${base}^{commit}" >/dev/null 2>&1; then
      range="${base}..${head}"
    else
      range="$(git rev-parse "$head")^!"
    fi
    fail=0
    for commit in $(git rev-list "$range" 2>/dev/null); do
      files=$(git -c core.quotePath=false diff-tree --no-commit-id --name-only -r "$commit" 2>/dev/null \
        | grep -E "$WORKFLOW_RE" || true)
      [ -z "$files" ] && continue
      msg_file=$(mktemp 2>/dev/null || echo "/tmp/harness-workflow-message.$$")
      git log -1 --format=%B "$commit" > "$msg_file"
      if ! require_authorization_trailer "$msg_file"; then
        echo "  commit ${commit:0:8} 修改了：" >&2
        printf '%s\n' "$files" | sed 's/^/    /' >&2
        fail=1
      fi
      rm -f "$msg_file"
    done
    exit "$fail"
    ;;
  *)
    echo "用法：verify-github-workflows.sh staged | commit-msg <message-file> | range [BASE] [HEAD]" >&2
    exit 2
    ;;
esac

exit 0
