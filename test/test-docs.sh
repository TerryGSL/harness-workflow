#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
S="$HW_ROOT/SKILL.md"
R="$HW_ROOT/README.md"
skill_has_frontmatter_name() { grep -qE '^name:[[:space:]]*harness-workflow' "$S"; }
skill_is_thin() { [ "$(wc -l < "$S")" -le 150 ]; }
skill_runs_init() { grep -q 'init.sh' "$S"; }
skill_no_reimplement() { grep -qE '不重造|不写.*team|orchestrat' "$S"; }
readme_has_nongoals() { grep -qiE 'non-goals|非目标' "$R"; }
readme_names_legacy() { grep -q 'harness-workflow.legacy' "$R"; }
skill_is_chinese() { grep -q '脚手架' "$S" || grep -q '指挥家' "$S" || grep -q '路由' "$S"; }
readme_is_chinese() { grep -q '精简' "$R"; }
readme_has_evidence_gate() { grep -qE '证据门|Harness-Type' "$R"; }

assert "SKILL.md frontmatter name=harness-workflow" skill_has_frontmatter_name
assert "SKILL.md ≤150 行" skill_is_thin
assert "SKILL.md runs init.sh" skill_runs_init
assert "SKILL.md 声明不重造(反 bloat)" skill_no_reimplement
assert "SKILL.md 是中文" skill_is_chinese
assert "README has NON-GOALS section" readme_has_nongoals
assert "README names the .legacy predecessor" readme_names_legacy
assert "README 是中文" readme_is_chinese
assert "README 讲证据门" readme_has_evidence_gate
finish
