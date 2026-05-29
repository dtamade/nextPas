#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

FILE="docs/PLATFORM_SUPPORT.md"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] top of $file:"
    sed -n '1,320p' "$file" || true
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

assert_contains "$FILE" "## 当前发布与平台验证入口" \
  "Platform support doc is missing the current release/platform entry section"
assert_contains "$FILE" "ROADMAP.md" \
  "Platform support doc is missing the current roadmap entrypoint"
assert_contains "$FILE" "2026-05-12-release-v1.5.0-formalization.md" \
  "Platform support doc is missing the current release-control plan entrypoint"
assert_contains "$FILE" "RELEASE_READINESS_V1.5.0.md" \
  "Platform support doc is missing the current release readiness entrypoint"
assert_contains "$FILE" "python3 scripts/compile_all_modules.py" \
  "Platform support doc is missing the Linux canonical compile command"
assert_contains "$FILE" "bash scripts/run_minimal_ci_gate.sh --fast-local" \
  "Platform support doc is missing the Linux canonical minimal gate command"
assert_contains "$FILE" "bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local" \
  "Platform support doc is missing the Linux focused gate command"
assert_contains "$FILE" "python3 scripts/check_code_style.py src" \
  "Platform support doc is missing the Linux style gate command"
assert_contains "$FILE" "bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local" \
  "Platform support doc is missing the Linux phase2 dry-run command"
assert_contains "$FILE" "tests/openssl/test_openssl_simple.pas" \
  "Platform support doc is missing the macOS focused smoke source path"
assert_contains "$FILE" "run_core_tests.ps1" \
  "Platform support doc no longer points Windows guidance at the real PowerShell test script"
assert_contains "$FILE" "run_winssl_tests.ps1" \
  "Platform support doc no longer points Windows guidance at the real WinSSL PowerShell script"

assert_not_contains "$FILE" "build_linux.sh" \
  "Platform support doc still treats build_linux.sh as default guidance"
assert_not_contains "$FILE" "run_core_tests.sh" \
  "Platform support doc still references the removed shell core-test script"
assert_not_contains "$FILE" "build_macos.sh" \
  "Platform support doc still treats build_macos.sh as default guidance"
assert_not_contains "$FILE" "当前默认 baseline 仍是 Linux local-first / pre-CI 链：" \
  "Platform support doc still presents the old Wave C baseline as the default platform entry"

echo "[PASS] platform support doc stays aligned with current platform guidance"
