#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_present() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

MBEDTLS_CONN="src/nextpas.core.tls.mbedtls.connection.pas"
MBEDTLS_CTX="src/nextpas.core.tls.mbedtls.context.pas"
OPENSSL_CONN="src/nextpas.core.tls.openssl.connection.pas"
OPENSSL_CTX="src/nextpas.core.tls.openssl.context.pas"
WOLFSSL_CONN="src/nextpas.core.tls.wolfssl.connection.pas"
WOLFSSL_CTX="src/nextpas.core.tls.wolfssl.context.pas"
WINSSL_CONN="src/nextpas.core.tls.winssl.connection.pas"
WINSSL_CTX="src/nextpas.core.tls.winssl.context.pas"
FREEPASCAL_CONN="src/nextpas.core.tls.freepascal.connection.pas"
FREEPASCAL_CTX="src/nextpas.core.tls.freepascal.context.pas"
FREEPASCAL_LIB="src/nextpas.core.tls.freepascal.lib.pas"

echo "[TEST] backend transport IStream migration contract"

require_present "$MBEDTLS_CONN" "FStream: IStream;" \
  "MbedTLS connection must store transport as IStream"
require_present "$MBEDTLS_CONN" "TMbedTLSIOContext" \
  "MbedTLS connection must define an IO context wrapper for callback transport"
require_present "$MBEDTLS_CONN" "constructor Create(AContext: ISSLContext; ASSLConfig: Pmbedtls_ssl_config; AStream: IStream);" \
  "MbedTLS connection must expose an IStream constructor"
require_present "$MBEDTLS_CTX" "WrapTStream(" \
  "MbedTLS context must bridge TStream callers through WrapTStream"
require_present "$MBEDTLS_CTX" "IoLimitReader(" \
  "MbedTLS context must read stream-backed material through IStream limit reader helpers"

require_present "$OPENSSL_CONN" "FStream: IStream;" \
  "OpenSSL connection must store transport as IStream"
require_present "$OPENSSL_CONN" "constructor Create(AContext: ISSLContext; AStream: IStream);" \
  "OpenSSL connection must expose an IStream constructor"
require_present "$OPENSSL_CTX" "BIO_new_mem_buf" \
  "OpenSSL context must keep memory BIO loading for stream-backed material"
require_present "$OPENSSL_CTX" "WrapTStream(" \
  "OpenSSL context must bridge TStream callers through WrapTStream"
require_present "$OPENSSL_CTX" "IoLimitReader(" \
  "OpenSSL context must bound stream-backed material reads through IStream helpers"

require_present "$WOLFSSL_CONN" "FStream: IStream;" \
  "WolfSSL connection must store transport as IStream"
require_present "$WOLFSSL_CONN" "constructor Create(AContext: ISSLContext; AStream: IStream);" \
  "WolfSSL connection must expose an IStream constructor"
require_present "$WOLFSSL_CTX" "WrapTStream(" \
  "WolfSSL context must bridge TStream callers through WrapTStream"
require_present "$WOLFSSL_CTX" "IoLimitReader(" \
  "WolfSSL context must read stream-backed material through IStream limit reader helpers"

require_present "$WINSSL_CONN" "FStream: IStream;" \
  "WinSSL connection must store transport as IStream"
require_present "$WINSSL_CONN" "constructor Create(AContext: ISSLContext; AStream: IStream);" \
  "WinSSL connection must expose an IStream constructor"
require_present "$WINSSL_CTX" "WrapTStream(" \
  "WinSSL context must bridge TStream callers through WrapTStream"
require_present "$WINSSL_CTX" "IoLimitReader(" \
  "WinSSL context must read stream-backed material through IStream limit reader helpers"

require_present "$FREEPASCAL_CONN" "FStream: IStream;" \
  "FreePascal connection must store transport as IStream"
require_present "$FREEPASCAL_CONN" "constructor Create(AContext: ISSLContext; AStream: IStream);" \
  "FreePascal connection must expose an IStream constructor"
require_present "$FREEPASCAL_CONN" "WrapIStream(" \
  "FreePascal connection must bridge IStream back to TStream where legacy helpers still require TStream"
require_present "$FREEPASCAL_CTX" "WrapTStream(" \
  "FreePascal context must bridge TStream callers through WrapTStream"
require_present "$FREEPASCAL_LIB" "nextpas.core.io.intf" \
  "FreePascal shared TLS library must import nextpas.core.io.intf for stream bridging"

echo "[PASS] backend transport IStream migration contract passed"
