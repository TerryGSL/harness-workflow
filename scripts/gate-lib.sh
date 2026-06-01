#!/usr/bin/env bash
# gate-lib.sh — shared patterns for the memory gate and the secret gate.
# Sourced by scripts/verify-memory.sh, scripts/ci-gate.sh, and .githooks/pre-commit
# so the client hook and the server-side CI check can never drift apart.

# Paths/files considered "significant" enough to require a memory record.
SIGNIFICANT_RE='^(src/|app/|lib/|libs/|pkg/|packages/|server/|client/|cmd/|web/|components/|pages/|routes/|api/|scripts/|tests?/|migrations?/|db/)|\.(sql|prisma|graphql|proto)$|schema|\.(test|spec)\.|^[^/]+\.(py|go|rs|rb|java|kt|ts|js|tsx|jsx)$|(^|/)(package\.json|pyproject\.toml|go\.mod|Cargo\.toml|Dockerfile|Makefile)$|^\.github/workflows/'

# Paths/files that must never be committed (secrets / credentials).
SECRET_RE='(^|/)\.env($|\.)|(^|/)secrets?/|(^|/)\.npmrc$|(^|/)\.pypirc$|(^|/)id_(rsa|ed25519|ecdsa)($|\.)|\.(pem|p12|pfx|key|keystore)$|(^|/)(credentials|\.aws/credentials)($|\.)|(^|/)\.netrc$'

# A commit message satisfies the memory escape hatch if it has a Memory: trailer.
MEMORY_TRAILER_RE='^Memory:[[:space:]]*[^[:space:]]+'
# Revert/rollback commits are exempt from the memory gate (回退类不被卡,避免诱导静默绕过).
MEMORY_EXEMPT_RE='^(Revert|Rollback|revert)'

# 证据门：任务类型声明 + 测试文件识别(verify-evidence 与 ci-gate 共享)
HARNESS_TYPE_RE='^Harness-Type:[[:space:]]*(trivial|bug|feature|refactor)'
TEST_FILE_RE='(^|/)tests?/|\.(test|spec)\.|_test\.|(^|/)test_[^/]*\.py$'
# 沉淀门:非 trivial commit 必须带 Harness-Record: <id> 且同 commit 改了 .harness/records/<id>.md
HARNESS_RECORD_RE='^Harness-Record:[[:space:]]*[^[:space:]]+'
# A changed-file list satisfies the gate if it adds/edits a memory artifact.
MEMORY_FILE_RE='^docs/memory/(cases|decisions)/.+\.md$'

# 风险分级(classify-risk.sh 用)。HIGH 只收「内容高危」信号——故意不收「文件数多」:
# 纯文件数不是危险,频繁触发会让 HIGH 确认沦为无脑 y，护栏变剧场(codex 告诫)。
RISK_DEP_RE='(^|/)(package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|go\.(mod|sum)|Cargo\.(toml|lock)|pyproject\.toml|requirements[^/]*\.txt|Pipfile(\.lock)?|Gemfile(\.lock)?|composer\.(json|lock))$'
RISK_SCHEMA_RE='\.(sql|prisma)$|(^|/)migrations?/'
RISK_CI_RE='^\.github/workflows/|(^|/)\.gitlab-ci\.yml$|(^|/)\.circleci/|(^|/)Jenkinsfile$'
# 文档-only:一段 diff 若全部文件命中 → 评 LOW(不打扰)。
DOCS_ONLY_RE='\.(md|markdown|txt|rst|adoc)$|(^|/)docs/|(^|/)LICENSE($|\.)|(^|/)\.gitignore$'
# HIGH 推送的显式确认 trailer(CI 不能问人，靠这个留痕)。
RISK_ACK_RE='^Risk-Ack:[[:space:]]*[^[:space:]]+'
# feature 设计来源 trailer:半机械化「脑暴先行」。只查存在不验质量(同 Reviewed-by),
# 逃生口 none:<理由>(必须非空)。接手查 claude-mem 是「接手动作」,不在此处——见 SKILL 接手提示。
BRAINSTORMED_RE='^Brainstormed-by:[[:space:]]*[^[:space:]]+'
