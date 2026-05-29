#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local text="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$text" "$file"; then
    fail "$message"
  fi
}

require_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$message"
  fi
}

script_file="tests/run_winssl_tests.ps1"
checklist_file="tests/windows/WINDOWS_VALIDATION_CHECKLIST.md"
runtime_test_file="tests/winssl/test_winssl_unit_comprehensive.pas"

echo "[TEST] winssl runtime callback markers contract"

require_fixed "$runtime_test_file" \
  "Verify callback set" \
  "Windows WinSSL comprehensive unit test must emit verify callback truth"
require_fixed "$runtime_test_file" \
  "Password callback unsupported as expected" \
  "Windows WinSSL comprehensive unit test must emit password callback unsupported truth"
require_fixed "$runtime_test_file" \
  "Info callback set" \
  "Windows WinSSL comprehensive unit test must emit info callback truth"

require_match "$script_file" \
  'function Write-CallbackSurfaceMarkers \{.*?test_winssl_unit_comprehensive\.lpi.*?Verify callback set.*?Password callback unsupported as expected.*?Info callback set.*?callback_surface verify=' \
  "tests/run_winssl_tests.ps1 must derive callback_surface markers from the WinSSL comprehensive unit-test output"
require_fixed "$script_file" \
  'Write-CallbackSurfaceMarkers -Test $test -Output $output' \
  "tests/run_winssl_tests.ps1 must emit callback_surface markers during runtime execution"

require_fixed "$checklist_file" \
  '[WINSSL-RUNTIME] callback_surface verify=pass password=unsupported info=pass' \
  "Windows validation checklist must document the callback_surface runtime marker"
require_fixed "$checklist_file" \
  '这条 marker 直接对应 `tests/winssl/test_winssl_unit_comprehensive.pas` 里的 WinSSL callback 粒度 truth：verify/info 已发布，password 仍 unsupported。' \
  "Windows validation checklist must explain the callback_surface runtime marker meaning"

echo "[PASS] winssl runtime callback markers contract passed"
