#!/usr/bin/env node
// gen-architecture-summary.mjs — 从 docs/code-map.json 机械生成 docs/ARCHITECTURE.md。
// 人读这份摘要(子系统→文件→一句职责 + 路由表),机器读 200KB 的 code-map.json。
// 确定性、无时间戳(像 code-map):pre-commit 在 code-map 刷新后重生成并 staged;
// ci-gate 用 cmp 防手改漂移(改内容要回去改 src 的 @purpose / 边界配置,不是改本文件)。
//
// 输入: docs/code-map.json(由 gen-code-map.mjs 产出,真相源)。
// 输出: docs/ARCHITECTURE.md(ARCH_OUT 可覆盖,供 ci 写 temp 比对)。
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const MAP = path.join(ROOT, 'docs/code-map.json');
const OUT = process.env.ARCH_OUT || path.join(ROOT, 'docs/ARCHITECTURE.md');

if (!fs.existsSync(MAP)) {
  process.stderr.write('gen-architecture: 缺 docs/code-map.json,先跑 node scripts/gen-code-map.mjs\n');
  process.exit(0); // 无 code-map = 本仓不用,空操作(别卡住无 src 的仓)
}
const cm = JSON.parse(fs.readFileSync(MAP, 'utf8'));

// 边界目录(来自同一份配置,与 @purpose 门同源)
let boundary = [];
try {
  const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, '.harness/code-map.config.json'), 'utf8'));
  if (Array.isArray(cfg.boundary)) boundary = cfg.boundary;
} catch {}

const files = cm.files || {};
const allPaths = Object.keys(files).sort();

// 顶层目录概览(src/ 下两级目录 → 文件数),给人一眼的版图
const dirCounts = {};
for (const f of allPaths) {
  const parts = f.split('/');
  const key = parts.slice(0, 3).join('/'); // e.g. src/shared/services
  dirCounts[key] = (dirCounts[key] || 0) + 1;
}

const esc = (s) => String(s).replace(/\|/g, '\\|').replace(/\n/g, ' ');

const lines = [];
lines.push('<!-- doc-status: generated · owner: scripts/gen-architecture-summary.mjs · 触发: src/ 或 code-map 变更自动重生成·勿手改 -->');
lines.push('# 架构地图（机械生成自 docs/code-map.json，勿手改）');
lines.push('');
lines.push('> 人读这份；机器读 `docs/code-map.json`（完整 exports/imports/路由事实）。');
lines.push('> 改这里的内容 = 去改 `src/` 文件首行的 `/** @purpose ... */`，或 `.harness/code-map.config.json` 的 boundary。');
lines.push('> 重生成：`node scripts/gen-architecture-summary.mjs`（pre-commit 自动跑）。');
lines.push('');
lines.push(`**规模**：${cm.counts?.files ?? allPaths.length} 个源文件 · ${cm.counts?.routes ?? 0} 条 API 路由 · locales=[${(cm.locales || []).join(', ')}]`);
lines.push('');

// ── 顶层版图 ──
lines.push('## 顶层版图（src 两级目录 → 文件数）');
lines.push('');
lines.push('| 目录 | 文件数 | 边界 |');
lines.push('| --- | ---: | :---: |');
for (const dir of Object.keys(dirCounts).sort()) {
  const isB = boundary.some((b) => dir === b || dir.startsWith(b + '/') || b.startsWith(dir + '/'));
  lines.push(`| \`${dir}\` | ${dirCounts[dir]} | ${isB ? '✔' : ''} |`);
}
lines.push('');

// ── 边界子系统:文件 → 职责 ──
lines.push('## 边界子系统（文件职责）');
lines.push('');
lines.push('> 边界目录见 `.harness/code-map.config.json`。`@purpose` 缺失=`⚠ 未标注职责`（由 verify-purpose 棘轮门逼平）。');
lines.push('');
let missingInArch = 0;
for (const b of boundary) {
  const inB = allPaths.filter((f) => f === b || f.startsWith(b + '/')).filter((f) => !/\.(test|spec)\.[jt]sx?$/.test(f));
  if (!inB.length) continue;
  lines.push(`### \`${b}\``);
  lines.push('');
  lines.push('| 文件 | 职责 |');
  lines.push('| --- | --- |');
  for (const f of inB) {
    const rel = f.slice(b.length + 1) || f.split('/').pop();
    const p = files[f]?.purpose;
    if (!p) missingInArch++;
    lines.push(`| \`${esc(rel)}\` | ${p ? esc(p) : '⚠ 未标注职责'} |`);
  }
  lines.push('');
}

// ── 路由表 ──
const routes = cm.routes || {};
const routePaths = Object.keys(routes).sort();
if (routePaths.length) {
  lines.push('## API 路由表');
  lines.push('');
  lines.push('| 方法 | 路由文件 | 职责 |');
  lines.push('| --- | --- | --- |');
  for (const f of routePaths) {
    const methods = (routes[f] || []).join(' ');
    const p = files[f]?.purpose || '';
    lines.push(`| \`${esc(methods)}\` | \`${esc(f)}\` | ${esc(p)} |`);
  }
  lines.push('');
}

lines.push('---');
lines.push(`_边界文件中仍 ${missingInArch} 个未标注 @purpose（verify-purpose 棘轮门会逼着逐步补平）。_`);
lines.push('');

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, lines.join('\n'));
process.stderr.write(`architecture: ${allPaths.length} files, ${routePaths.length} routes, boundary-missing-@purpose=${missingInArch} → ${path.relative(ROOT, OUT)}\n`);
