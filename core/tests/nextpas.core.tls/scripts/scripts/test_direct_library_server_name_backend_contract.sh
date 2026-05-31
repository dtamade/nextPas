#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

require_fixed() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

check_backend_source() {
  local file="$1"
  local class_name="$2"

  require_fixed "ValidateDirectLibraryConnectionScope(" "$file" \
    "$file no longer validates direct-library connection-scoped TSSLConfig fields"
  require_fixed "ServerName is client-scoped. Server-side connections ignore context-level ServerName;" "$file" \
    "$file no longer rejects server-side direct-library ServerName defaults"
  require_fixed "${class_name}.CreateContext received TSSLConfig.ServerName as deprecated context-level " "$file" \
    "$file no longer documents client-side direct-library ServerName compatibility warning"
}

check_backend_source "src/nextpas.core.tls.openssl.backed.pas" "TOpenSSLLibrary"
check_backend_source "src/nextpas.core.tls.freepascal.lib.pas" "TFreePascalSSLLibrary"
check_backend_source "src/nextpas.core.tls.mbedtls.lib.pas" "TMbedTLSLibrary"
check_backend_source "src/nextpas.core.tls.wolfssl.lib.pas" "TWolfSSLLibrary"
check_backend_source "src/nextpas.core.tls.winssl.lib.pas" "TWinSSLLibrary"

require_fixed "tests/test_openssl_library_default_config_server_name_clarification.pas" "docs/plans/2026-05-21-direct-library-server-name-backend-proof.md" \
  "plan no longer records the existing OpenSSL direct-library ServerName proof file"
require_fixed "tests/test_freepascal_library_default_config_server_name_clarification.pas" "docs/plans/2026-05-21-direct-library-server-name-backend-proof.md" \
  "plan no longer records the existing FreePascal direct-library ServerName proof file"
require_fixed "tests/test_mbedtls_wolfssl_library_default_config_server_name_clarification.pas" "docs/plans/2026-05-21-direct-library-server-name-backend-proof.md" \
  "plan no longer records the new MbedTLS/WolfSSL direct-library ServerName proof file"

runtime_file="tests/test_mbedtls_wolfssl_library_default_config_server_name_clarification.pas"
require_fixed "@CreateMbedTLSLibrary" "$runtime_file" \
  "optional backend runtime proof no longer exercises the MbedTLS direct-library path"
require_fixed "@CreateWolfSSLLibrary" "$runtime_file" \
  "optional backend runtime proof no longer exercises the WolfSSL direct-library path"
require_fixed "TryCreateInitializedLibrary(ABackend: TSSLLibraryType;" "$runtime_file" \
  "optional backend runtime proof no longer centralizes optional-backend initialization and skip handling"
require_fixed "backend not available on this platform" "$runtime_file" \
  "optional backend runtime proof no longer preserves explicit optional-backend skip semantics"
require_fixed "sslMbedTLS," "$runtime_file" \
  "optional backend runtime proof no longer names the MbedTLS backend enum"
require_fixed "sslWolfSSL," "$runtime_file" \
  "optional backend runtime proof no longer names the WolfSSL backend enum"
require_fixed "deprecated context-level SNI compatibility" "$runtime_file" \
  "optional backend runtime proof no longer asserts the compatibility warning truth"
require_fixed "ServerName is client-scoped" "$runtime_file" \
  "optional backend runtime proof no longer asserts the server-side rejection truth"

echo "[PASS] direct-library ServerName compatibility backend proof stays aligned"
