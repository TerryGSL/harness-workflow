#!/usr/bin/env bash
source "$(dirname "$0")/run.sh" --lib
S="$HW_ROOT/SKILL.md"
name_ok(){ grep -qE '^name:[[:space:]]*harness-workflow' "$S"; }
le_150(){ [ "$(wc -l < "$S")" -le 150 ]; }
router(){ for k in trivial bug feature refactor; do grep -qi "$k" "$S"||return 1; done; }
evidence(){ grep -q 'Harness-Type' "$S"; }
guide(){ grep -qi '明确需求边界' "$S" && grep -qi '独立审查' "$S"; }
subagent(){ grep -qi 'subagent' "$S" && grep -q 'brief.sh' "$S"; }
degraded(){ grep -q '降级' "$S"; }
mech(){ grep -qE '证据|hook|CI' "$S"; }
assert "name=harness-workflow" name_ok
assert "≤150 行" le_150
assert "四档 router" router
assert "讲 Harness-Type 证据要求" evidence
assert "feature 指南使用原生计划/审查流程" guide
assert "有 subagent 同步协议(brief.sh)" subagent
assert "有 degraded" degraded
assert "点明执行权在 hook/CI(机械)" mech
finish
