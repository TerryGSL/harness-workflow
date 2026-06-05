#!/usr/bin/env bash
# verify-purpose.sh — 棘轮门:边界目录(.harness/code-map.config.json 的 boundary)文件必须有
# `@purpose` 头注释,且「缺失集只减不增」。治"门全绿但没人知道文件干啥"——@purpose 被 code-map
# 采集却从不强制。基准存**缺失路径集**(非计数):
#   - 当前缺失集里出现**基准里没有的路径** = 新增/改动的边界文件没写 @purpose → fail(真违例)。
#   - 当前缺失集是基准的子集(补了几个) → --fix 收紧基准(还债);check 只提醒。
# 用路径集而非计数:堵住"加一个缺 @purpose 的新文件、同时补掉一个旧的,计数不变蒙混过关"(codex P2)。
#
#   --fix  : pre-commit 用。基准缺失则建立(并 git add);新缺失 → fail;有补全 → 收紧基准。
#   (默认): CI 严格。**基准缺失→fail**(strict 不自建,防静默重基准绕过棘轮·codex P1);新缺失 → fail。
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "verify-purpose: not a git repo" >&2; exit 1; }
cd "$ROOT"
[ -f scripts/gen-code-map.mjs ] || exit 0   # 本仓不用 code-map
[ -d src ] || exit 0                          # 脚本/文档仓
[ -f docs/code-map.json ] || exit 0           # 还没生成 code-map(由 verify-code-map 那条门报)
command -v node >/dev/null 2>&1 || { echo "⚠ verify-purpose: node 缺失,跳过" >&2; exit 0; }

mode="${1:-check}"
baseline_file=".harness/purpose-baseline"

# 当前缺失路径集(排序去空)
cur=$(node -e 'const d=require("./docs/code-map.json");for(const f of (d.boundaryMissingPurpose||[]).slice().sort())console.log(f);' | sed '/^$/d' | sort -u)

# 基准
if [ ! -f "$baseline_file" ]; then
  if [ "$mode" = "--fix" ]; then
    printf '%s\n' "$cur" | sed '/^$/d' > "$baseline_file"
    git add "$baseline_file" 2>/dev/null || true
    echo "verify-purpose: 建立 @purpose 缺失基准($(printf '%s\n' "$cur" | grep -c .) 个)" >&2
    exit 0
  fi
  echo "✗ verify-purpose: 缺基准文件 $baseline_file(strict 不自建,防静默重基准绕过棘轮)。" >&2
  echo "  本地跑 \`bash scripts/verify-purpose.sh --fix\` 生成并提交。" >&2
  exit 1
fi
base=$(sed '/^$/d' "$baseline_file" | sort -u)

# 新缺失 = cur - base(出现了基准里没有的缺失路径 = 新文件没写 @purpose)
new_missing=$(comm -23 <(printf '%s\n' "$cur") <(printf '%s\n' "$base"))
if [ -n "$new_missing" ]; then
  echo "✗ verify-purpose: 新增/改动的边界文件缺 @purpose 头(首行加 /** @purpose <一句职责> */):" >&2
  printf '%s\n' "$new_missing" | sed 's/^/    /' >&2
  echo "  (边界目录见 .harness/code-map.config.json;补掉旧的不能抵新增的缺失。)" >&2
  exit 1
fi

# 还债:cur ⊊ base(补全了一些) → 收紧基准
fixed=$(comm -13 <(printf '%s\n' "$cur") <(printf '%s\n' "$base"))
if [ -n "$fixed" ]; then
  if [ "$mode" = "--fix" ]; then
    printf '%s\n' "$cur" > "$baseline_file"; git add "$baseline_file" 2>/dev/null || true
    echo "verify-purpose: 还债 — 基准收紧(移除 $(printf '%s\n' "$fixed" | grep -c .) 个已补)" >&2
  else
    echo "verify-purpose: 有 $(printf '%s\n' "$fixed" | grep -c .) 个已补,提醒跑 --fix 收紧基准" >&2
  fi
fi
exit 0
