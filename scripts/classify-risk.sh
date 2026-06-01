#!/usr/bin/env bash
# classify-risk.sh <base> <head> — 纯机械给一段 diff 评推送风险。无 LLM。
# pre-push(客户端，HIGH→问一次)和 ci-gate(服务端，HIGH→要 Risk-Ack 留痕)共用同一份，
# 客户端 hook 和 CI 永不漂移。判不准往重里放。
#   HIGH   = 命中内容高危：密钥 / 改依赖清单 / 改 db schema·migration / 改 CI 配置
#   LOW    = 改动「全是」文档(.md/docs/LICENSE…)
#   MEDIUM = 其余(默认；含纯代码大改——文件数不进 HIGH，见 gate-lib 说明)
# 用法: classify-risk.sh <base> <head>   base 空或不存在 → 只看 head 单 commit 的 diff
# 输出: HIGH|MEDIUM|LOW 到 stdout；人读原因到 stderr。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/gate-lib.sh"

BASE="${1:-}"; HEAD="${2:-HEAD}"

if [ -n "$BASE" ] && git rev-parse -q --verify "${BASE}^{commit}" >/dev/null 2>&1; then
  files=$(git -c core.quotePath=false diff --name-only "$BASE" "$HEAD" 2>/dev/null || true)
else
  # 无有效 base(新分支首推/root commit) → 看 HEAD 这一 commit 自身的 diff
  files=$(git -c core.quotePath=false diff-tree --no-commit-id --name-only -r "$HEAD" 2>/dev/null || true)
fi

files=$(printf '%s\n' "$files" | grep -v '^[[:space:]]*$' || true)
if [ -z "$files" ]; then echo "LOW"; echo "（无文件变更）" >&2; exit 0; fi

reasons=""
add() { reasons="${reasons:+$reasons, }$1"; }
printf '%s\n' "$files" | grep -qE "$SECRET_RE"     && add "密钥类文件"
printf '%s\n' "$files" | grep -qE "$RISK_DEP_RE"   && add "改依赖清单"
printf '%s\n' "$files" | grep -qE "$RISK_SCHEMA_RE" && add "改 db schema/migration"
printf '%s\n' "$files" | grep -qE "$RISK_CI_RE"    && add "改 CI 配置"

if [ -n "$reasons" ]; then
  echo "HIGH"; printf 'HIGH：%s\n' "$reasons" >&2; exit 0
fi
# LOW：没有任何「非文档」文件
if ! printf '%s\n' "$files" | grep -qvE "$DOCS_ONLY_RE"; then
  echo "LOW"; echo "（纯文档变更）" >&2; exit 0
fi
echo "MEDIUM"; echo "（常规代码变更）" >&2
