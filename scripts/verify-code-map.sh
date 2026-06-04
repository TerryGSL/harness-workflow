#!/usr/bin/env bash
# verify-code-map.sh — 保证 docs/code-map.json 与 src/ 同步(lockfile 式)。
#   --fix   : 重生成 + git add(pre-commit 用;永不失败,自动保鲜,不挡自驱循环)
#   (默认) : 严格校验,漂了就 fail(ci-gate 用;抓绕过 hook 的提交)
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "verify-code-map: not a git repo" >&2; exit 1; }
cd "$ROOT"

command -v node >/dev/null 2>&1 || { echo "⚠ verify-code-map: node 缺失,跳过(降级不阻断)" >&2; exit 0; }
[ -f scripts/gen-code-map.mjs ] || { echo "⚠ verify-code-map: 无 gen-code-map.mjs,跳过" >&2; exit 0; }

mode="${1:-check}"

if [ "$mode" = "--fix" ]; then
  node scripts/gen-code-map.mjs 2>/dev/null || { echo "✗ code-map 生成失败" >&2; exit 1; }
  git add docs/code-map.json 2>/dev/null || true
  exit 0
fi

# 严格:重生成后若与已提交内容有差 → 漂了
node scripts/gen-code-map.mjs 2>/dev/null || { echo "✗ code-map 生成失败" >&2; exit 1; }
if ! git diff --quiet -- docs/code-map.json 2>/dev/null; then
  echo "✗ code-map 过期:src/ 变了但 docs/code-map.json 没同步。" >&2
  echo "  修:node scripts/gen-code-map.mjs && git add docs/code-map.json" >&2
  exit 1
fi
exit 0
