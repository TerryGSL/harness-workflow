#!/usr/bin/env bash
# verify-code-map.sh — 保证 docs/code-map.json 与 src/ 同步(lockfile 式)。
#   --fix  : 重生成(atomic temp→mv)+ 仅在变了时 git add(pre-commit;不挡循环)。无 node 本地降级 exit 0。
#   (默认): 严格校验,写 temp 比对、**不动工作树**。无 node **fail-closed**(CI 必须有 node,漂移门不能形同虚设)。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "verify-code-map: not a git repo" >&2; exit 1; }
cd "$ROOT"
[ -f scripts/gen-code-map.mjs ] || exit 0   # 无生成器=本仓不用 code-map,跳过
[ -d src ] || exit 0                          # 无 src/=脚本/文档仓,不需要 code-map 门(codex P1:无src仓别卡)

mode="${1:-check}"

if [ "$mode" = "--fix" ]; then
  command -v node >/dev/null 2>&1 || { echo "⚠ verify-code-map(--fix): node 缺失,本地降级跳过" >&2; exit 0; }
  tmp=$(mktemp) || exit 1
  if CODE_MAP_OUT="$tmp" node scripts/gen-code-map.mjs 2>/dev/null; then
    if ! cmp -s "$tmp" docs/code-map.json 2>/dev/null; then
      mkdir -p docs; mv "$tmp" docs/code-map.json && git add docs/code-map.json 2>/dev/null || true
    else rm -f "$tmp"; fi
  else rm -f "$tmp"; echo "✗ code-map 生成失败" >&2; exit 1; fi
  exit 0
fi

# 严格(check):CI/服务端用。无 node = fail-closed(不能让漂移门在缺 node 的 CI 上静默放行)。
command -v node >/dev/null 2>&1 || { echo "✗ verify-code-map(check): node 缺失,无法校验 code-map 漂移(CI 须装 node)。" >&2; exit 1; }
tmp=$(mktemp) || exit 1
CODE_MAP_OUT="$tmp" node scripts/gen-code-map.mjs 2>/dev/null || { rm -f "$tmp"; echo "✗ code-map 生成失败" >&2; exit 1; }
if ! cmp -s "$tmp" docs/code-map.json 2>/dev/null; then
  echo "✗ code-map 过期:src/ 变了但 docs/code-map.json 没同步。" >&2
  echo "  修:node scripts/gen-code-map.mjs && git add docs/code-map.json" >&2
  rm -f "$tmp"; exit 1
fi
rm -f "$tmp"; exit 0
