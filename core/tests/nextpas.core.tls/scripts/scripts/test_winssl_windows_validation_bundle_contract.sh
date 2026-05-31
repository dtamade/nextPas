#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$name" "unexpected pattern still present in $file: $pattern"
  else
    pass "$name"
  fi
}

checklist="tests/windows/WINDOWS_VALIDATION_CHECKLIST.md"
bundle="tests/windows/VALIDATION_BUNDLE.md"
quick_runner="tests/quick_winssl_validation.ps1"
full_runner="tests/run_winssl_tests.ps1"
status_report="docs/test_reports/WINSSL_BACKEND_STATUS_REPORT.md"

printf '[TEST] WinSSL Windows validation bundle contract\n'

require_match "$quick_runner" '\$ScriptDir = Split-Path -Parent \$MyInvocation\.MyCommand\.Path' \
  'quick validation script resolves its own directory'
require_match "$quick_runner" '\$WinsslDir = Join-Path \$ScriptDir "winssl"' \
  'quick validation script targets tests/winssl'
require_match "$quick_runner" 'Set-Location \$WinsslDir' \
  'quick validation script no longer depends on caller cwd'

require_match "$full_runner" '\$ScriptDir = Split-Path -Parent \$MyInvocation\.MyCommand\.Path' \
  'broader WinSSL suite resolves its own directory'
require_match "$full_runner" '\$WinsslDir = Join-Path \$ScriptDir "winssl"' \
  'broader WinSSL suite targets tests/winssl'
require_match "$full_runner" 'Set-Location \$WinsslDir' \
  'broader WinSSL suite no longer depends on caller cwd'
require_absent "$full_runner" '\[switch\]\$Verbose' \
  'broader WinSSL suite does not redeclare the common -Verbose parameter'
require_match "$full_runner" "ContainsKey\\('Verbose'\\)" \
  'broader WinSSL suite gates verbose output via common -Verbose'
require_match "$full_runner" '\.\.\\integration\\test_backend_comparison\.lpi' \
  'broader WinSSL suite points backend comparison to tests/integration'

require_match "$checklist" 'tests/quick_winssl_validation\.ps1' \
  'checklist points to quick WinSSL smoke entrypoint'
require_match "$checklist" 'run_winssl_tests\.ps1' \
  'checklist points to current WinSSL runners'
require_match "$checklist" 'scripts/run_wave_b_windows_gate\.ps1' \
  'checklist points to current Wave B Windows gate'
require_match "$checklist" 'tests/run_winssl_tests\.ps1' \
  'checklist points to broader manual WinSSL suite'
require_match "$checklist" '\[WINSSL-RUNTIME\]' \
  'checklist documents the stable broader-suite evidence markers'
require_match "$checklist" 'test-reports/wave_b_windows_gate_summary_' \
  'checklist documents current gate summary artifact'
require_absent "$checklist" 'Run-WindowsValidation\.ps1' \
  'checklist no longer references removed main validation template script'
require_absent "$checklist" 'Run-QuickValidation\.ps1' \
  'checklist no longer references removed quick validation template script'
require_absent "$checklist" 'test_cert_load' \
  'checklist no longer references removed certificate-load template program'
require_absent "$checklist" 'test_factory_mode' \
  'checklist no longer references removed factory template program'
require_absent "$checklist" 'ROLLBACK_PLAN\.md' \
  'checklist no longer references nonexistent rollback template'
require_absent "$checklist" 'WINDOWS_VALIDATION_REPORT\.md' \
  'checklist no longer references nonexistent report template'

require_match "$bundle" 'tests/quick_winssl_validation\.ps1' \
  'bundle inventory includes quick WinSSL smoke script'
require_match "$bundle" 'run_winssl_tests\.ps1' \
  'bundle inventory includes current WinSSL runner(s)'
require_match "$bundle" 'run_openssl_tests\.ps1' \
  'bundle inventory includes current OpenSSL minimal runner'
require_match "$bundle" 'scripts/run_wave_b_windows_gate\.ps1' \
  'bundle inventory includes Wave B Windows gate'
require_match "$bundle" 'scripts/validate_all_modules\.ps1' \
  'bundle inventory includes module validation script'
require_match "$bundle" 'tests/winssl/' \
  'bundle inventory points to actual WinSSL test directory'
require_match "$bundle" 'tests/integration/test_backend_comparison\.lpi' \
  'bundle inventory points to cross-backend comparison project'
require_match "$bundle" '\[WINSSL-RUNTIME\]' \
  'bundle inventory documents the stable broader-suite evidence markers'
require_match "$bundle" 'test-reports/wave_b_windows_gate_summary_' \
  'bundle inventory documents current Windows gate artifact'
require_match "$bundle" '不属于当前 bundle 的旧模板名称' \
  'bundle inventory explicitly quarantines stale template names'

require_match "$status_report" 'tests/windows/WINDOWS_VALIDATION_CHECKLIST\.md' \
  'WinSSL status report links to current checklist'
require_match "$status_report" 'tests/windows/VALIDATION_BUNDLE\.md' \
  'WinSSL status report links to current bundle inventory'

printf '[PASS] WinSSL Windows validation bundle contract passed\n'
