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
for f in .githooks/pre-commit .githooks/commit-msg .githooks/pre-push scripts/verify-memory.sh scripts/gate-lib.sh \
         scripts/verify-purpose.sh scripts/verify-living-docs.sh scripts/gen-architecture-summary.mjs scripts/verify-doc-sprawl.sh; do
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
  printf '%s\n' "$msg" | head -1 | grep -qiE '^merge[ (]' && continue   # merge commit 豁免(合并的是已过门提交)
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

# 5. code-map 同步(服务端不可绕):重生成 docs/code-map.json,与已提交内容有差=漂了。
#    pre-commit 用 --fix 自动保鲜;这里严格校验,抓「绕过 hook / 手改 src 没重生成」。
if [ -x "$DIR/verify-code-map.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-code-map.sh ) || fail=1
fi

# 6. 文档保鲜(服务端不可绕):死链(纸面承诺指向不存在文件)/locale 漂移/生成文档过期。
if [ -x "$DIR/verify-doc-freshness.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-doc-freshness.sh ) || fail=1
fi

# 7. 入口文件行数治理(单一规则源,与 pre-commit 同调)。CI 已 checkout,直接对工作树跑。
if [ -x "$DIR/verify-governance.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-governance.sh ) || fail=1
fi

# 8. claude-mem 注入不得入库(根治 AGENTS.md/CLAUDE.md 污染)。pre-commit 从 index 剥离,这里抓绕过。
for f in AGENTS.md CLAUDE.md; do
  if git show "${HEAD}:$f" 2>/dev/null | grep -qF '<claude-mem-context>'; then
    echo "✗ ci-gate：${f} 含 claude-mem 注入块(<claude-mem-context>)，不得入库(应由 strip-mem-injection 剥离)"; fail=1
  fi
done

# 9. @purpose 棘轮门(服务端严格):边界文件缺职责数不得高于基准。抓"绕过 hook 加了无 @purpose 的边界文件"。
if [ -x "$DIR/verify-purpose.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-purpose.sh ) || fail=1
fi

# 10. 架构摘要同步(服务端不可绕):重生成 docs/ARCHITECTURE.md,与已提交内容有差=漂了(手改或没重生成)。
if [ -f "$DIR/gen-architecture-summary.mjs" ] && command -v node >/dev/null 2>&1; then
  ( cd "$(git rev-parse --show-toplevel)"
    { [ -d src ] && [ -f docs/code-map.json ]; } || exit 0   # 无 src/无 code-map = 不需要架构摘要(codex P1)
    [ -f docs/ARCHITECTURE.md ] || { echo "✗ ci-gate：缺 docs/ARCHITECTURE.md(跑 node scripts/gen-architecture-summary.mjs)"; exit 1; }
    tmp=$(mktemp) || exit 1
    if ARCH_OUT="$tmp" node scripts/gen-architecture-summary.mjs 2>/dev/null && cmp -s "$tmp" docs/ARCHITECTURE.md; then rm -f "$tmp"
    else rm -f "$tmp"; echo "✗ ci-gate：docs/ARCHITECTURE.md 过期:src/@purpose 变了但没重生成。跑 node scripts/gen-architecture-summary.mjs"; exit 1; fi
  ) || fail=1
fi

# 11. living 文档新鲜度(服务端严格):living 必须注册合同 + 不得落后触发源过多提交。
if [ -x "$DIR/verify-living-docs.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-living-docs.sh check ) || fail=1
fi

# 12. 文档泛滥防复发(服务端严格):根层非白名单 *.md → fail。
if [ -x "$DIR/verify-doc-sprawl.sh" ]; then
  ( cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-doc-sprawl.sh check ) || fail=1
fi

[ "$fail" -eq 0 ] && echo "ci-gate：通过"
exit "$fail"
