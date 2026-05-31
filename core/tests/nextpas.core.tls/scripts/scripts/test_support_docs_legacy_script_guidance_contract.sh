#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

FCL_FILE="docs/FCL_DEPENDENCIES.md"
ASSESS_FILE="docs/testing/TEST_COVERAGE_ASSESSMENT.md"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] top of $file:"
    sed -n '1,260p' "$file" || true
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    rg -n -F -- "$pattern" "$file" || true
    exit 1
  fi
}

assert_contains "$FCL_FILE" "## 当前默认验证链路" \
  "FCL dependencies doc lost the current validation chain section"
assert_contains "$FCL_FILE" "python3 scripts/compile_all_modules.py" \
  "FCL dependencies doc lost the canonical compile command"
assert_contains "$FCL_FILE" "bash scripts/run_minimal_ci_gate.sh --fast-local" \
  "FCL dependencies doc lost the canonical minimal gate command"
assert_contains "$FCL_FILE" "bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local" \
  "FCL dependencies doc lost the canonical Phase 2 dry-run command"
assert_contains "$FCL_FILE" "历史 \`build_linux.sh\` 仍可作为兼容入口保留，但不再是默认文档路径。" \
  "FCL dependencies doc no longer labels build_linux.sh as historical compatibility guidance"

assert_not_contains "$FCL_FILE" "## 使用我们的构建脚本" \
  "FCL dependencies doc still presents the legacy script section as the active path"
assert_not_contains "$FCL_FILE" "项目提供了预配置的构建脚本，自动处理路径配置：" \
  "FCL dependencies doc still describes the legacy scripts as the default workflow"

assert_contains "$ASSESS_FILE" "这是一个历史测试评估快照。" \
  "Test coverage assessment doc no longer labels itself as a historical snapshot"
assert_contains "$ASSESS_FILE" "python3 scripts/compile_all_modules.py" \
  "Test coverage assessment doc lost the canonical compile command"
assert_contains "$ASSESS_FILE" "bash scripts/run_minimal_ci_gate.sh --fast-local" \
  "Test coverage assessment doc lost the canonical minimal gate command"
assert_contains "$ASSESS_FILE" "bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local" \
  "Test coverage assessment doc lost the canonical Phase 2 dry-run command"

assert_not_contains "$ASSESS_FILE" "build_linux.sh" \
  "Test coverage assessment doc still promotes build_linux.sh"
assert_not_contains "$ASSESS_FILE" "run_tests_linux.sh" \
  "Test coverage assessment doc still promotes run_tests_linux.sh"

echo "[PASS] support docs keep the canonical validation chain and historical labels"
