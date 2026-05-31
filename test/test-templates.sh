#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
T="$HW_ROOT/templates"
agents_le_60() { [ "$(wc -l < "$T/AGENTS.md")" -le 60 ]; }
project_le_100() { [ "$(wc -l < "$T/PROJECT.md")" -le 100 ]; }
claude_le_5() { [ "$(wc -l < "$T/CLAUDE.md")" -le 5 ]; }
claude_points_to_agents() { grep -q 'AGENTS.md' "$T/CLAUDE.md"; }
agents_has_mode_line() { grep -qiE '^(mode:|- mode:|loose|strict)' "$T/AGENTS.md" && grep -qi 'mode' "$T/AGENTS.md"; }
agents_has_memory_section() { grep -q 'docs/memory/cases' "$T/AGENTS.md"; }
no_aimode_template() { [ ! -e "$T/ai-mode" ]; }
agents_has_priority() { grep -q '优先级' "$T/AGENTS.md"; }

assert "AGENTS.md ≤ 60 lines" agents_le_60
assert "PROJECT.md ≤ 100 lines" project_le_100
assert "CLAUDE.md ≤ 5 lines" claude_le_5
assert "CLAUDE.md points to AGENTS.md" claude_points_to_agents
assert "AGENTS.md carries a Mode line (absorbs .ai-mode)" agents_has_mode_line
assert "AGENTS.md documents memory triggers" agents_has_memory_section
assert "no separate ai-mode template exists" no_aimode_template
assert "AGENTS.md 有优先级链" agents_has_priority
finish
