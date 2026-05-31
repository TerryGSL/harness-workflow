#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
S="$HW_ROOT/skill/harness-workflow/SKILL.md"
R="$HW_ROOT/README.md"
skill_has_frontmatter_name() { grep -qE '^name:[[:space:]]*harness-workflow' "$S"; }
skill_is_thin() { [ "$(wc -l < "$S")" -le 60 ]; }
skill_runs_init() { grep -q 'init.sh' "$S"; }
skill_forbids_orchestration() { grep -qiE 'no session|不含.*lifecycle|one-shot|一次性' "$S"; }
readme_has_nongoals() { grep -qiE 'non-goals|非目标' "$R"; }
readme_names_legacy() { grep -q 'harness-workflow.legacy' "$R"; }
skill_is_chinese() { grep -q '脚手架' "$S"; }
readme_is_chinese() { grep -q '精简' "$R"; }

assert "SKILL.md frontmatter name=harness-workflow" skill_has_frontmatter_name
assert "SKILL.md is thin (≤60 lines)" skill_is_thin
assert "SKILL.md runs init.sh" skill_runs_init
assert "SKILL.md forbids orchestration/lifecycle" skill_forbids_orchestration
assert "SKILL.md 是中文" skill_is_chinese
assert "README has NON-GOALS section" readme_has_nongoals
assert "README names the .legacy predecessor" readme_names_legacy
assert "README 是中文" readme_is_chinese
finish
