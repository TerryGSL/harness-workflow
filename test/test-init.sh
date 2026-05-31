#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
INIT="$HW_ROOT/init.sh"

run_init() { local d="$1"; ( cd "$d" && bash "$INIT" >/dev/null 2>&1 ); }

scaffolds_files() {
  local d; d=$(mktarget); run_init "$d"
  local ok=0
  for f in AGENTS.md CLAUDE.md docs/PROJECT.md \
           scripts/verify-memory.sh \
           .githooks/pre-commit .githooks/commit-msg .githooks/pre-push; do
    [ -e "$d/$f" ] || ok=1
  done
  [ -d "$d/docs/memory/cases" ] && [ -d "$d/docs/memory/decisions" ] || ok=1
  rm -rf "$d"; return $ok
}
omits_optional_files() {  # minimalism: init must NOT create these
  local d; d=$(mktarget); run_init "$d"
  local ok=0
  [ -e "$d/WORK.md" ] && ok=1
  [ -e "$d/.ai-mode" ] && ok=1
  [ -d "$d/docs/memory/archive" ] && ok=1
  rm -rf "$d"; return $ok
}
sets_hookspath() {
  local d; d=$(mktarget); run_init "$d"
  local v; v=$(cd "$d" && git config core.hooksPath)
  rm -rf "$d"; [ "$v" = ".githooks" ]
}
is_idempotent() {  # user edits to AGENTS.md survive re-init
  local d; d=$(mktarget); run_init "$d"
  echo "MY EDIT" >> "$d/AGENTS.md"; run_init "$d"
  grep -q "MY EDIT" "$d/AGENTS.md"; local rc=$?
  rm -rf "$d"; return $rc
}

assert "init scaffolds all files + memory dirs" scaffolds_files
assert "init omits optional files (WORK/.ai-mode/archive)" omits_optional_files
assert "init sets core.hooksPath=.githooks" sets_hookspath
assert "init is idempotent (keeps user edits)" is_idempotent
finish
