#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MBEDTLS_LIB="$ROOT_DIR/core/src/nextpas.core.tls.mbedtls.lib.pas"
BUILDER_SRC="$ROOT_DIR/core/src/nextpas.core.tls.context.builder.pas"
MBEDTLS_CONTEXT_TEST="$ROOT_DIR/core/tests/nextpas.core.tls/mbedtls/test_mbedtls_context_contract.pas"
CAPABILITY_CACHE_TEST="$ROOT_DIR/core/tests/nextpas.core.tls/test_capability_cache.pas"
MBEDTLS_SOURCES=("$ROOT_DIR"/src/nextpas.core.tls.mbedtls*.pas)

fail() {
  echo "[FAIL] $1"
  exit 1
}

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    echo "[PASS] $message"
  else
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$message"
  else
    echo "[PASS] $message"
  fi
}

echo "[TEST] MbedTLS OCSP capability doc truth contract"

require_fixed "$MBEDTLS_LIB" \
  "Result.OCSPStaplingSupport := sslSupportNone;  // 需要手动实现" \
  "MbedTLS source must keep OCSP stapling capability at none"
require_fixed "$MBEDTLS_LIB" \
  "sslFeatOCSPStapling: Result := False;   // 需要手动实现" \
  "MbedTLS feature gating must keep sslFeatOCSPStapling disabled"
require_fixed "$MBEDTLS_LIB" \
  "Optimized for embedded systems; early-data, OCSP stapling, and certificate transparency " \
  "MbedTLS KnownIssues must continue to record OCSP stapling unsupported truth"

require_fixed "$ROOT_DIR/core/src/nextpas.core.tls.mbedtls.certificate.pas" \
  "MbedTLS VerifyEx has no OCSP/CRL revocation material for sslCertVerifyCheckRevocation/sslCertVerifyCheckCRL/sslCertVerifyCheckOCSP" \
  "MbedTLS source must keep the fail-closed VerifyEx OCSP/CRL rejection path"

for needle in \
  "CreateOCSPRequest" \
  "SendOCSPRequest" \
  "VerifyOCSPResponse" \
  "CheckCertificateStatus"; do
  if rg -n "$needle" "${MBEDTLS_SOURCES[@]}" >/dev/null 2>&1; then
    fail "MbedTLS source must not publish an online OCSP verification helper: $needle"
  else
    echo "[PASS] MbedTLS source does not publish $needle"
  fi
done

require_fixed "$BUILDER_SRC" \
  "Configured server_ocsp_stapled_response_file requires a backend that implements ISSLServerOCSPStaplingContext" \
  "Builder source must keep fail-fast behavior for unsupported server OCSP stapling backends"
require_fixed "$MBEDTLS_CONTEXT_TEST" \
  "Fail('ISSLServerOCSPStaplingContext should NOT be exposed', 'MbedTLS does not support OCSP stapling')" \
  "MbedTLS context contract must keep server OCSP optional interface absent"
require_fixed "$CAPABILITY_CACHE_TEST" \
  "MbedTLS OCSPStaplingSupport should remain none on the current capability model" \
  "Capability cache test must keep MbedTLS OCSP support at none"



echo "[PASS] MbedTLS OCSP capability doc truth contract passed"
