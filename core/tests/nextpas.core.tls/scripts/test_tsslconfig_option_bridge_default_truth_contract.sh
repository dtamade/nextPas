#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_ref="docs/reference/API_REFERENCE.md"

check_constructor_normalization() {
  local file="$1"

  if ! rg -n --quiet 'TSSLFactory\.NormalizeConfig\(FDefaultConfig\);' "$file"; then
    echo "[FAIL] $file does not normalize constructor-level FDefaultConfig"
    exit 1
  fi
}

check_registration_creator() {
  local file="$1"
  local pattern="$2"

  if ! rg -F -n --quiet "$pattern" "$file"; then
    echo "[FAIL] $file no longer registers the backend through its explicit creator function"
    exit 1
  fi
}

check_constructor_normalization "src/nextpas.core.tls.openssl.backed.pas"
check_constructor_normalization "src/nextpas.core.tls.freepascal.lib.pas"
check_constructor_normalization "src/nextpas.core.tls.winssl.lib.pas"
check_constructor_normalization "src/nextpas.core.tls.mbedtls.lib.pas"
check_constructor_normalization "src/nextpas.core.tls.wolfssl.lib.pas"

check_registration_creator "src/nextpas.core.tls.openssl.backed.pas" "TSSLFactory.RegisterLibrary(sslOpenSSL, @CreateOpenSSLLibrary,"
check_registration_creator "src/nextpas.core.tls.freepascal.lib.pas" "TSSLFactory.RegisterLibrary(sslFreePascal, @CreateFreePascalSSLLibrary,"
check_registration_creator "src/nextpas.core.tls.winssl.lib.pas" "TSSLFactory.RegisterLibrary(sslWinSSL, @CreateWinSSLLibrary,"
check_registration_creator "src/nextpas.core.tls.mbedtls.lib.pas" "TSSLFactory.RegisterLibrary(sslMbedTLS, @CreateMbedTLSLibrary,"
check_registration_creator "src/nextpas.core.tls.wolfssl.lib.pas" "TSSLFactory.RegisterLibrary(sslWolfSSL, @CreateWolfSSLLibrary,"

if ! rg -n --quiet 'FDefaultConfig\.EnableSessionTickets := True;' "src/nextpas.core.tls.freepascal.lib.pas"; then
  echo "[FAIL] FreePascal library constructor no longer preserves session-ticket default truth"
  exit 1
fi

if ! rg -F -n --quiet '`ISSLLibrary.GetDefaultConfig(...)` / `CreateDefaultConfig(...)` 这类 fresh default-config surface 返回时，也必须保持这些 compatibility booleans 与最终 `Options` 真相一致。' "$api_ref"; then
  echo "[FAIL] API reference no longer records option-bridge truth on fresh default-config surfaces"
  exit 1
fi

echo "[PASS] TSSLConfig option-bridge default truth remains aligned on fresh default-config surfaces"
