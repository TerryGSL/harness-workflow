#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
CR="$HW_ROOT/scripts/classify-risk.sh"

# 造临时 git repo,内置 scripts/{classify-risk,gate-lib}.sh，回显路径。
setup() {
  local d; d=$(mktemp -d)
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t \
    && mkdir -p scripts \
    && cp "$HW_ROOT/scripts/classify-risk.sh" "$HW_ROOT/scripts/gate-lib.sh" scripts/ \
    && echo "# base" > README.md && git add -A && git commit -q -m base )
  echo "$d"
}
# 在 repo 里加一个文件并提交,回显 base sha(提交前的 HEAD)。
commit_with() { # <dir> <path> <content>
  ( cd "$1" && git rev-parse HEAD )  # echo base
  ( cd "$1" && mkdir -p "$(dirname "$2")" 2>/dev/null; printf '%s\n' "$3" > "$2" \
    && git add -A && git commit -q -m "change $2" )
}
classify_eq() { # <path> <content> <expected>
  local d b; d=$(setup); b=$(commit_with "$d" "$2" "$3" | head -1)
  local r; r=$( cd "$d" && bash scripts/classify-risk.sh "$b" HEAD 2>/dev/null )
  rm -rf "$d"; [ "$r" = "$1" ]
}

docs_low()    { classify_eq LOW    README.md "more docs"; }
docsdir_low() { classify_eq LOW    docs/x.md "doc"; }
code_medium() { classify_eq MEDIUM src/app.js "console.log(1)"; }
dep_high()    { classify_eq HIGH   package.json '{"deps":1}'; }
schema_high() { classify_eq HIGH   migrations/001.sql "create table t(id int)"; }
prisma_high() { classify_eq HIGH   schema.prisma "model X {}"; }
ci_high()     { classify_eq HIGH   .github/workflows/ci.yml "on: push"; }
secret_high() { classify_eq HIGH   id_rsa "PRIVATE"; }
# 文件数多但全是普通代码 → 仍 MEDIUM(故意不因文件数升 HIGH)
manyfiles_not_high() {
  local d b; d=$(setup); b=$( cd "$d" && git rev-parse HEAD )
  ( cd "$d" && mkdir -p src && for i in 1 2 3 4 5; do echo "x$i" > "src/f$i.js"; done && git add -A && git commit -q -m many )
  local r; r=$( cd "$d" && bash scripts/classify-risk.sh "$b" HEAD 2>/dev/null )
  rm -rf "$d"; [ "$r" = "MEDIUM" ]
}
# 无 base(看 HEAD 单 commit)也能分级
nobase_works() {
  local d; d=$(setup)
  ( cd "$d" && echo '{}' > package.json && git add -A && git commit -q -m dep )
  local r; r=$( cd "$d" && bash scripts/classify-risk.sh "" HEAD 2>/dev/null )
  rm -rf "$d"; [ "$r" = "HIGH" ]
}

assert "纯 .md → LOW"            docs_low
assert "docs/ 目录 → LOW"        docsdir_low
assert "普通代码 → MEDIUM"       code_medium
assert "改依赖清单 → HIGH"       dep_high
assert "改 migration sql → HIGH" schema_high
assert "改 prisma schema → HIGH" prisma_high
assert "改 CI workflow → HIGH"   ci_high
assert "密钥文件 → HIGH"         secret_high
assert "多文件但普通代码 → MEDIUM(不因文件数升 HIGH)" manyfiles_not_high
assert "无 base 看单 commit 也能评 HIGH" nobase_works
finish
