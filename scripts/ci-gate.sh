#!/usr/bin/env bash
# ci-gate.sh [BASE] [HEAD] — server-side invariant (the real, unbypassable layer).
# Verifies, for every commit in the range, that code-touching commits carry a memory
# record (case/decision file OR a Memory: trailer); that no secret-like files are
# tracked at HEAD; and that the hook files still exist at HEAD (anti self-disable).
# Exits non-zero on any violation. Reuses gate-lib.sh so rules match the client hook.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/gate-lib.sh"

BASE="${1:-}"; HEAD="${2:-HEAD}"
if [ -n "$BASE" ] && git rev-parse -q --verify "${BASE}^{commit}" >/dev/null 2>&1; then
  range="${BASE}..${HEAD}"
else
  range="$(git rev-parse "$HEAD")^!"   # first push / no base -> just the tip commit
fi

fail=0

# 1. Hook files must still exist at HEAD (a commit cannot quietly remove the gate).
for f in .githooks/pre-commit .githooks/commit-msg .githooks/pre-push scripts/verify-memory.sh scripts/gate-lib.sh; do
  git cat-file -e "${HEAD}:$f" 2>/dev/null || { echo "✗ ci-gate：HEAD 缺少必需文件：$f"; fail=1; }
done

# 2. Per-commit: memory 门 + 证据门(同一遍, 不早退以免漏检)。
for c in $(git rev-list "$range" 2>/dev/null); do
  files=$(git -c core.quotePath=false diff-tree --no-commit-id --name-only -r "$c" 2>/dev/null || true)
  sig=$(printf '%s\n' "$files" | grep -E "$SIGNIFICANT_RE" || true)
  [ -z "$sig" ] && continue
  msg=$(git log -1 --format=%B "$c")
  printf '%s\n' "$msg" | head -1 | grep -qE "$MEMORY_EXEMPT_RE" && continue
  printf '%s\n' "$msg" | grep -qiE '^(Revert|Rollback):' && continue
  # memory 门
  mem=$(printf '%s\n' "$files" | grep -E "$MEMORY_FILE_RE" || true)
  if [ -z "$mem" ] && ! printf '%s\n' "$msg" | grep -qiE "$MEMORY_TRAILER_RE"; then
    echo "✗ ci-gate：commit ${c:0:8} 动了代码但没记 memory（无 case/decision，也无 'Memory:' trailer）"; fail=1
  fi
  # 证据门
  ctype=$(printf '%s\n' "$msg" | grep -iE "$HARNESS_TYPE_RE" | grep -oiE '(trivial|bug|feature|refactor)' | head -1 | tr 'A-Z' 'a-z')
  if [ -z "$ctype" ]; then
    echo "✗ ci-gate：commit ${c:0:8} 改了代码但未声明 Harness-Type"; fail=1
  else
    # 沉淀门(非 trivial):必须带 Harness-Record 且同 commit 改了对应 record.md
    if [ "$ctype" != "trivial" ]; then
      rid=$(printf '%s\n' "$msg" | grep -iE "$HARNESS_RECORD_RE" | head -1 | sed -E 's/^[Hh]arness-[Rr]ecord:[[:space:]]*//' | tr -d '[:space:]')
      if [ -z "$rid" ]; then echo "✗ ci-gate：commit ${c:0:8} ($ctype) 缺 Harness-Record trailer"; fail=1
      elif ! printf '%s\n' "$files" | grep -qxF ".harness/records/$rid.md"; then
        echo "✗ ci-gate：commit ${c:0:8} 未在同 commit 改 .harness/records/$rid.md(沉淀未绑定)"; fail=1; fi
    fi
    case "$ctype" in
    bug)
      if printf '%s\n' "$files" | grep -qE "$TEST_FILE_RE"; then :
      elif printf '%s\n' "$msg" | grep -qiE '^No-Repro:[[:space:]]*[^[:space:]]'; then :
      else echo "✗ ci-gate：bug commit ${c:0:8} 无测试/无 No-Repro"; fail=1; fi ;;
    feature)
      if printf '%s\n' "$msg" | grep -qiE '^Plan:[[:space:]]*[^[:space:]]'; then :
      elif printf '%s\n' "$files" | grep -qiE '^docs/.*plan.*\.md$'; then :
      else echo "✗ ci-gate：feature commit ${c:0:8} 缺 Plan(镜像 verify-evidence)"; fail=1; fi
      printf '%s\n' "$msg" | grep -qiE '^Reviewed-by:[[:space:]]*[^[:space:]]' || { echo "✗ ci-gate：feature commit ${c:0:8} 缺 Reviewed-by"; fail=1; }
      printf '%s\n' "$msg" | grep -qiE "$BRAINSTORMED_RE" || { echo "✗ ci-gate：feature commit ${c:0:8} 缺 Brainstormed-by"; fail=1; } ;;
    refactor)
      printf '%s\n' "$msg" | grep -qiE '^Behavior-Unchanged:[[:space:]]*(true|yes|是)' || { echo "✗ ci-gate：refactor commit ${c:0:8} 缺 Behavior-Unchanged"; fail=1; } ;;
  esac; fi
done

# 3. No secret-like files tracked at HEAD.
secrets=$(git ls-tree -r --name-only "$HEAD" 2>/dev/null | grep -E "$SECRET_RE" | grep -vE '\.(example|template|sample|dist)$' || true)
if [ -n "$secrets" ]; then
  echo "✗ ci-gate：仓库里 track 了密钥类文件："; printf '%s\n' "$secrets" | sed 's/^/    /'
  fail=1
fi

# 4. 风险分级镜像 pre-push(服务端不可绕):HIGH 推送(密钥/依赖/schema/CI)必须有
#    commit 带 'Risk-Ack: <理由>' 留痕——CI 不能问人,只能要凭据。客户端 pre-push 用同一个
#    classify-risk.sh，规则永不漂移。测试失败仍由 per-commit/工作树测试独立硬 block,不在此处放行。
# 仅在有真实 BASE(已有远程历史的增量推送)时启用:首次推送整个仓库必然含 CI/依赖等文件,
# 评 HIGH 无意义且会卡住建仓。增量改 CI/依赖/schema 才是要盯的。
if [ -x "$DIR/classify-risk.sh" ] && [ -n "$BASE" ] && git rev-parse -q --verify "${BASE}^{commit}" >/dev/null 2>&1; then
  risk=$(bash "$DIR/classify-risk.sh" "$BASE" "$HEAD" 2>/dev/null || echo MEDIUM)
  if [ "$risk" = "HIGH" ] && ! git log "$range" --format=%B 2>/dev/null | grep -qiE "$RISK_ACK_RE"; then
    echo "✗ ci-gate：本次推送评级 HIGH(密钥/依赖/db schema/CI)，但无 commit 带 'Risk-Ack: <理由>' 留痕。"
    fail=1
  fi
fi

# 5. 入口文件行数治理(单一规则源,与 pre-commit 同调)。CI 已 checkout,直接对工作树跑。
if [ -x "$DIR/verify-governance.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-governance.sh ) || fail=1
fi

[ "$fail" -eq 0 ] && echo "ci-gate：通过"
exit "$fail"
