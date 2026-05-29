#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -A expected_labels=(
  ["tests/diagnostic/test_error_handling.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/diagnostic/test_error_handling_comprehensive.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/examples/test_lib_core_functionality.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/mbedtls/test_mbedtls_context_contract.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/security/test_input_validation.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/security/test_memory_safety.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/test_connection_builder_hostname_precedence.pas"]="INTENTIONAL_COMPAT"
  ["tests/test_context_builder_server_servername_runtime_consistency.pas"]="INTENTIONAL_COMPAT"
  ["tests/test_cross_backend_client_context_server_name_clarification.pas"]="INTENTIONAL_COMPAT"
  ["tests/test_freepascal_context_server_name_inheritance.pas"]="INTENTIONAL_COMPAT"
  ["tests/test_sslctxboth_client_capability_clarification.pas"]="INTENTIONAL_COMPAT"
  ["tests/test_wolfssl_framework.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/unit/test_winssl_comprehensive.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/winssl/test_winssl_context_comprehensive.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/winssl/test_winssl_library_basic.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/winssl/test_winssl_mtls_skeleton.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/winssl/test_winssl_unit_comprehensive.pas"]="INTENTIONAL_API_SURFACE"
  ["tests/wolfssl/test_wolfssl_context_contract.pas"]="INTENTIONAL_API_SURFACE"
)

pattern='(Context|Ctx|LCtx|LContext|LClientCtx)[0-9]*\.SetServerName\('

has_direct_context_call() {
  local file="$1"
  rg -n "$pattern" "$file" | rg -v '^[0-9]+:\s*(procedure|function)\s+' >/dev/null
}

for file in "${!expected_labels[@]}"; do
  label="${expected_labels[$file]}"
  if ! has_direct_context_call "$file"; then
    echo "[FAIL] expected direct context ServerName coverage was not found: $file"
    exit 1
  fi

  if ! rg -n --quiet "$label" "$file"; then
    echo "[FAIL] missing $label classification in $file"
    exit 1
  fi
done

mapfile -t candidate_files < <(rg -l -g '*.pas' "$pattern" tests || true)

for file in "${candidate_files[@]}"; do
  if has_direct_context_call "$file"; then
    if [[ -z "${expected_labels[$file]+x}" ]]; then
      echo "[FAIL] unexpected direct context ServerName surface remains in active test: $file"
      rg -n "$pattern" "$file" | rg -v '^[0-9]+:\s*(procedure|function)\s+' || true
      exit 1
    fi
  fi
done

echo "[PASS] active direct context ServerName tests are explicitly classified and confined"
