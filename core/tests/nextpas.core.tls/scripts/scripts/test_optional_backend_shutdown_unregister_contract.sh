#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FACTORY_FILE="$ROOT_DIR/src/nextpas.core.tls.factory.pas"
MBEDTLS_FILE="$ROOT_DIR/src/nextpas.core.tls.mbedtls.lib.pas"
WOLFSSL_FILE="$ROOT_DIR/src/nextpas.core.tls.wolfssl.lib.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

for file in "$FACTORY_FILE" "$MBEDTLS_FILE" "$WOLFSSL_FILE"; do
  [[ -f "$file" ]] || fail "missing source file: ${file#$ROOT_DIR/}"
done

if ! rg -n --fixed-strings -- "class procedure UnregisterLibraryForProcessShutdown(ALibType: TSSLLibraryType);" "$FACTORY_FILE" >/dev/null; then
  fail "factory must expose a shutdown-safe unregister helper for backend units"
fi

if ! rg -n --fixed-strings -- "class procedure TSSLFactory.UnregisterLibraryForProcessShutdown(ALibType: TSSLLibraryType);" "$FACTORY_FILE" >/dev/null; then
  fail "factory must implement the shutdown-safe unregister helper"
fi

if ! rg -n --fixed-strings -- "GSkipFinalizeOnDestroy" "$MBEDTLS_FILE" >/dev/null; then
  fail "mbedtls backend must track when shutdown-time destroy should skip library finalization"
fi

if ! rg -n --fixed-strings -- "if FInitialized and (not GSkipFinalizeOnDestroy) then" "$MBEDTLS_FILE" >/dev/null; then
  fail "mbedtls backend destructor must skip Finalize during shutdown-safe unregister"
fi

if ! rg -n --fixed-strings -- "procedure UnregisterMbedTLSBackendForProcessShutdown;" "$MBEDTLS_FILE" >/dev/null; then
  fail "mbedtls backend must provide a shutdown-safe unregister path"
fi

if ! rg -n --fixed-strings -- "TSSLFactory.UnregisterLibraryForProcessShutdown(sslMbedTLS);" "$MBEDTLS_FILE" >/dev/null; then
  fail "mbedtls backend shutdown path must use the factory shutdown-safe unregister helper"
fi

if ! rg -n --fixed-strings -- "finalization" "$MBEDTLS_FILE" >/dev/null || \
   ! rg -n --fixed-strings -- "UnregisterMbedTLSBackendForProcessShutdown;" "$MBEDTLS_FILE" >/dev/null; then
  fail "mbedtls backend finalization must use the shutdown-safe unregister path"
fi

if ! rg -n --fixed-strings -- "GSkipFinalizeOnDestroy" "$WOLFSSL_FILE" >/dev/null; then
  fail "wolfssl backend must track when shutdown-time destroy should skip library finalization"
fi

if ! rg -n --fixed-strings -- "if FInitialized and (not GSkipFinalizeOnDestroy) then" "$WOLFSSL_FILE" >/dev/null; then
  fail "wolfssl backend destructor must skip Finalize during shutdown-safe unregister"
fi

if ! rg -n --fixed-strings -- "procedure UnregisterWolfSSLBackendForProcessShutdown;" "$WOLFSSL_FILE" >/dev/null; then
  fail "wolfssl backend must provide a shutdown-safe unregister path"
fi

if ! rg -n --fixed-strings -- "TSSLFactory.UnregisterLibraryForProcessShutdown(sslWolfSSL);" "$WOLFSSL_FILE" >/dev/null; then
  fail "wolfssl backend shutdown path must use the factory shutdown-safe unregister helper"
fi

if ! rg -n --fixed-strings -- "finalization" "$WOLFSSL_FILE" >/dev/null || \
   ! rg -n --fixed-strings -- "UnregisterWolfSSLBackendForProcessShutdown;" "$WOLFSSL_FILE" >/dev/null; then
  fail "wolfssl backend finalization must use the shutdown-safe unregister path"
fi

echo "[PASS] optional backend shutdown unregister contract passed"
