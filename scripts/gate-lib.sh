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
# A changed-file list satisfies the gate if it adds/edits a memory artifact.
MEMORY_FILE_RE='^docs/memory/(cases|decisions)/.+\.md$'
