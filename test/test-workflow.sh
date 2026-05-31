#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
W="$HW_ROOT/templates/WORKFLOW.md"
has_grading() { grep -q '任务分级' "$W"; }
has_four_types() { for k in trivial bug feature refactor; do grep -qi "$k" "$W" || return 1; done; }
has_tdd() { grep -qE '会失败的测试|失败测试' "$W"; }
has_independent_verify() { grep -q '独立验证' "$W"; }
has_breaker() { grep -q '连续' "$W"; }
has_degraded() { grep -q '降级' "$W"; }
has_parallel() { grep -q '并行' "$W"; }
le_40() { [ "$(wc -l < "$W")" -le 40 ]; }   # 狠砍后参考卡上限 40
agents_points_to_workflow() { grep -q 'docs/WORKFLOW.md' "$HW_ROOT/templates/AGENTS.md"; }
assert "WORKFLOW.md 有任务分级" has_grading
assert "WORKFLOW.md 覆盖四档任务类型" has_four_types
assert "WORKFLOW.md 含先写失败测试(bug)" has_tdd
assert "WORKFLOW.md 含独立验证(feature)" has_independent_verify
assert "WORKFLOW.md 含连续失败停下" has_breaker
assert "WORKFLOW.md 含 degraded 降级" has_degraded
assert "WORKFLOW.md 含并行约定" has_parallel
assert "WORKFLOW.md ≤ 40 行(参考卡,不许长回引擎)" le_40
assert "AGENTS.md 指向 docs/WORKFLOW.md" agents_points_to_workflow
finish
