#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
# 全部用临时 HOME，绝不碰真实 ~/.claude
symlinks_skill() {
  local home; home=$(mktemp -d)
  ( cd "$HW_ROOT" && HOME="$home" bash install.sh >/dev/null 2>&1 )
  local rc=1; [ -L "$home/.claude/skills/harness-workflow" ] && rc=0
  rm -rf "$home"; return $rc
}
force_replaces_existing() {
  local home; home=$(mktemp -d); mkdir -p "$home/.claude/skills"
  ln -s /tmp/old-somewhere "$home/.claude/skills/harness-workflow"
  ( cd "$HW_ROOT" && HOME="$home" bash install.sh --force >/dev/null 2>&1 )
  local rc=1
  [ "$(readlink "$home/.claude/skills/harness-workflow")" = "$HW_ROOT" ] \
    && ls "$home/.claude/skills/"harness-workflow.legacy* >/dev/null 2>&1 && rc=0
  rm -rf "$home"; return $rc
}
refuses_without_force() {
  local home; home=$(mktemp -d); mkdir -p "$home/.claude/skills"
  ln -s /tmp/old-somewhere "$home/.claude/skills/harness-workflow"
  ( cd "$HW_ROOT" && HOME="$home" bash install.sh >/dev/null 2>&1 ); local rc=$?
  rm -rf "$home"; return $rc   # 期望非0(拒绝覆盖)
}
assert "install symlink 新 skill 到 ~/.claude/skills" symlinks_skill
assert "install --force 接管并把旧的备份成 .legacy" force_replaces_existing
refute "install 无 --force 不覆盖已存在" refuses_without_force
finish
