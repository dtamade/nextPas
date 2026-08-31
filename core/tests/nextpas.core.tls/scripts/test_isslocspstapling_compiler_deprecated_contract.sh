#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"

count_declaration() {
  local pattern="$1"
  perl -0ne "my \$n = () = /$pattern/g; print \$n;" "$base_file"
}

expect_count() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "[FAIL] $message"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    exit 1
  fi
}

require_fixed() {
  local file="$1"
  local text="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$text" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

expect_count \
  "$(count_declaration "function GetOCSPStaplingEnabled\\: Boolean;\\s*deprecated 'Use ISSLOCSPStapling\\.GetOCSPStaplingEnabled';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetOCSPStaplingEnabled declaration"
expect_count \
  "$(count_declaration "function GetOCSPResponse\\: TBytes;\\s*deprecated 'Use ISSLOCSPStapling\\.GetOCSPResponse';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetOCSPResponse declaration"
expect_count \
  "$(count_declaration "function IsOCSPResponseVerified\\: Boolean;\\s*deprecated 'Use ISSLOCSPStapling\\.IsOCSPResponseVerified';")" \
  "1" \
  "expected exactly one compiler-deprecated core IsOCSPResponseVerified declaration"
expect_count \
  "$(count_declaration "function GetOCSPResponseStatus\\: string;\\s*deprecated 'Use ISSLOCSPStapling\\.GetOCSPResponseStatus';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetOCSPResponseStatus declaration"




declare -A expected_suppression_counts=(
  ["core/tests/nextpas.core.tls/mbedtls/test_mbedtls_ocsp_capability.pas"]=1
  ["core/tests/nextpas.core.tls/openssl/test_ocsp_connection_verification_regression.pas"]=1
  ["core/tests/nextpas.core.tls/test_openssl_connection_ocsp_storectx_issuer_contract.pas"]=1
  ["core/tests/nextpas.core.tls/test_wolfssl_ocsp_stapling_contract.pas"]=1
)

for file in "${!expected_suppression_counts[@]}"; do
  expected="${expected_suppression_counts[$file]}"
  count=$(rg -F -c '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$file")
  if (( count < expected )); then
    echo "[FAIL] expected at least $expected OCSP deprecation warning suppressions in $file, found $count"
    exit 1
  fi
done

echo "[PASS] ISSLOCSPStapling compiler deprecation is aligned across source, docs, and intentional residual tests"
