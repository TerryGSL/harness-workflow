#!/usr/bin/env node
// gen-code-map.mjs — 机械生成 docs/code-map.json(事实,非 LLM 散文)。
// 零上下文 agent 冷启动读这份;CI/pre-commit 校验它与 src/ 同步(像 lockfile)。
// 抽事实:文件树 / exports / 本地 imports / route 方法 / @purpose 头注释 / locales / 配对测试。
// 通用版(harness-workflow skill):locale 目录自动探测;边界目录可用 .harness/code-map.config.json 覆盖。
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const SRC = path.join(ROOT, 'src');
// 输出路径可被 CODE_MAP_OUT 覆盖(verify-code-map 写 temp 比对,不污染工作树)。
const OUT = process.env.CODE_MAP_OUT || path.join(ROOT, 'docs/code-map.json');
const HAS_SRC = fs.existsSync(SRC);
// 无 src/(脚本型/文档型仓):仍写一份「空但合法」的 map,**不 exit 0 跳过**——
// 否则 verify-doc-freshness「有生成器就要产物」会把这类仓永久卡死(codex P1)。

// 边界目录(应有 @purpose 头):默认空(不强制),项目可在 .harness/code-map.config.json 配 {"boundary": ["src/services", ...]}
let BOUNDARY = [];
try {
  const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, '.harness/code-map.config.json'), 'utf8'));
  if (Array.isArray(cfg.boundary)) BOUNDARY = cfg.boundary;
} catch {}
const isBoundary = (f) => BOUNDARY.some((b) => f.startsWith(b));

function walk(dir) {
  let out = [];
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      if (ent.name === 'node_modules' || ent.name.startsWith('.')) continue;
      out = out.concat(walk(p));
    } else if (/\.(ts|tsx|js|jsx)$/.test(ent.name) && !ent.name.startsWith('._')) {
      out.push(p);
    }
  }
  return out;
}
const rel = (p) => path.relative(ROOT, p).split(path.sep).join('/');

const purposeOf = (t) => {
  const m = t.slice(0, 1500).match(/@purpose\s+(.+)/);
  return m ? m[1].trim() : '';
};
// best-effort 正则抽取(非 AST):命名 + default + `export { a, b as c }`。讲结构够用,别当强事实。
const exportsOf = (t) => {
  const named = [...t.matchAll(/export\s+(?:async\s+)?(?:function|const|let|var|class|type|interface|enum)\s+([A-Za-z0-9_$]+)/g)].map((m) => m[1]);
  const def = /export\s+default\s+(?:async\s+)?(?:function|class)\s+([A-Za-z0-9_$]+)/.exec(t);
  if (def) named.push(def[1]);
  else if (/export\s+default\b/.test(t)) named.push('default');
  // export { a, b as c } —— 取对外名(as 右侧,否则原名)
  for (const m of t.matchAll(/export\s*\{([^}]*)\}/g)) {
    for (const part of m[1].split(',')) {
      const id = part.trim().split(/\s+as\s+/).pop().trim();
      if (/^[A-Za-z0-9_$]+$/.test(id) && id !== 'default') named.push(id);
    }
  }
  return named.filter((v, i, a) => a.indexOf(v) === i).sort();
};
const localImportsOf = (t) => {
  const out = [...t.matchAll(/from\s+["']([^"']+)["']/g)].map((m) => m[1]);
  // side-effect import "./x" + dynamic import("./x")
  for (const m of t.matchAll(/import\s+["']([^"']+)["']/g)) out.push(m[1]);
  for (const m of t.matchAll(/import\(\s*["']([^"']+)["']\s*\)/g)) out.push(m[1]);
  return out
    .filter((s) => s.startsWith('@/') || s.startsWith('.'))
    .filter((v, i, a) => a.indexOf(v) === i)
    .sort();
};
const routeMethodsOf = (t, f) => {
  if (!f.endsWith('/route.ts') && !f.endsWith('/route.js')) return undefined;
  // 认 export (async )function GET / export const GET = / export { GET }
  const ms = ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'HEAD', 'OPTIONS'].filter(
    (m) =>
      new RegExp(`export\\s+(?:async\\s+)?(?:function|const|let|var)\\s+${m}\\b`).test(t) ||
      new RegExp(`export\\s*\\{[^}]*\\b${m}\\b`).test(t),
  );
  return ms.length ? ms : undefined;
};

const allFiles = (HAS_SRC ? walk(SRC) : []).map(rel).sort();
const fileSet = new Set(allFiles);
const files = {};
const boundaryMissingPurpose = [];
for (const file of allFiles) {
  const text = fs.readFileSync(path.join(ROOT, file), 'utf8');
  const isTest = /\.(test|spec)\.[jt]sx?$/.test(file);
  const purpose = purposeOf(text);
  const entry = {
    kind: file.includes('/app/') ? 'app' : isTest ? 'test' : 'module',
    exports: exportsOf(text),
    imports: localImportsOf(text),
    purpose,
  };
  const methods = routeMethodsOf(text, file);
  if (methods) entry.methods = methods;
  if (!isTest) {
    const tests = [
      file.replace(/\.([jt]sx?)$/, '.test.$1'),
      file.replace(/\.([jt]sx?)$/, '.spec.$1'),
    ].filter((t) => fileSet.has(t));
    if (tests.length) entry.tests = tests;
  }
  files[file] = entry;
  if (isBoundary(file) && !isTest && !purpose) boundaryMissingPurpose.push(file);
}

// locales 自动探测常见 messages 目录
let locales = [];
for (const d of ['src/config/locale/messages', 'src/i18n/messages', 'src/messages', 'messages', 'src/locales']) {
  const abs = path.join(ROOT, d);
  if (fs.existsSync(abs)) {
    locales = fs
      .readdirSync(abs, { withFileTypes: true })
      .filter((e) => e.isDirectory())
      .map((e) => e.name)
      .sort();
    if (locales.length) break;
  }
}

const routes = {};
for (const [f, e] of Object.entries(files)) if (e.methods) routes[f] = e.methods;

const out = {
  schemaVersion: 1,
  generatedBy: 'scripts/gen-code-map.mjs',
  counts: { files: allFiles.length, routes: Object.keys(routes).length },
  locales,
  routes,
  files,
  boundaryMissingPurpose,
};
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out, null, 2) + '\n');
process.stderr.write(
  `code-map: ${allFiles.length} files, ${Object.keys(routes).length} routes, locales=[${locales.join(',')}], boundary-missing-@purpose=${boundaryMissingPurpose.length}\n`,
);
