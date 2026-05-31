#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
W="$HW_ROOT/templates/WORKFLOW.md"
has_grading() { grep -q '任务分级' "$W"; }
has_four_types() { for k in trivial bug feature refactor; do grep -qi "$k" "$W" || return 1; done; }
has_tdd() { grep -q 'TDD' "$W" || grep -q '失败测试' "$W"; }
has_rollback() { grep -q '回退' "$W"; }
has_degraded() { grep -q '降级' "$W"; }
le_150() { [ "$(wc -l < "$W")" -le 150 ]; }
agents_points_to_workflow() { grep -q 'docs/WORKFLOW.md' "$HW_ROOT/templates/AGENTS.md"; }
assert "WORKFLOW.md 有任务分级" has_grading
assert "WORKFLOW.md 覆盖四档任务类型" has_four_types
assert "WORKFLOW.md 含 TDD/失败测试" has_tdd
assert "WORKFLOW.md 含失败回退" has_rollback
assert "WORKFLOW.md 含 degraded 不静默" has_degraded
assert "WORKFLOW.md ≤ 150 行" le_150
assert "AGENTS.md 指向 docs/WORKFLOW.md" agents_points_to_workflow
finish
