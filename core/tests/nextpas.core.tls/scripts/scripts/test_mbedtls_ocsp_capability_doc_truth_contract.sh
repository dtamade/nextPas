#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MBEDTLS_LIB="$ROOT_DIR/src/nextpas.core.tls.mbedtls.lib.pas"
MBEDTLS_DOC="$ROOT_DIR/docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md"
BUILDER_SRC="$ROOT_DIR/src/nextpas.core.tls.context.builder.pas"
MBEDTLS_CONTEXT_TEST="$ROOT_DIR/tests/mbedtls/test_mbedtls_context_contract.pas"
BACKEND_CONTRACT_TEST="$ROOT_DIR/tests/contract/test_backend_contract.pas"
CAPABILITY_CACHE_TEST="$ROOT_DIR/tests/test_capability_cache.pas"
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

require_fixed "$ROOT_DIR/src/nextpas.core.tls.mbedtls.certificate.pas" \
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
require_fixed "$BACKEND_CONTRACT_TEST" \
  "* - MbedTLS: Early Data / manual server OCSP stapling" \
  "Backend contract must continue to classify MbedTLS as unsupported for manual server OCSP stapling"
require_fixed "$CAPABILITY_CACHE_TEST" \
  "MbedTLS OCSPStaplingSupport should remain none on the current capability model" \
  "Capability cache test must keep MbedTLS OCSP support at none"

require_fixed "$MBEDTLS_DOC" \
  "| OCSP | ❌ 当前 capability 不发布 | 当前 backend 没有 shipped online OCSP verification public surface；如需相关 revocation workflow，需由应用层在 fafafa.ssl 已发布 surface 之外自行实现 |" \
  "MbedTLS dedicated matrix must describe generic OCSP as unpublished capability"
require_fixed "$MBEDTLS_DOC" \
  '| OCSP Stapling | ❌ 当前 capability 不发布 | 当前 backend 不暴露 `ISSLOCSPStapling` / `ISSLServerOCSPStaplingContext`；`server_ocsp_stapled_response_file` 配置会在 builder 侧 fail-fast |' \
  "MbedTLS dedicated matrix must describe OCSP stapling as unpublished capability"
require_fixed "$MBEDTLS_DOC" \
  "1. **OCSP / OCSP Stapling**: 当前 backend 不发布 online OCSP 或 stapled-response public capability；如需相关 revocation workflow，需在 fafafa.ssl 已发布 surface 之外自行实现" \
  "MbedTLS limitation note must distinguish unpublished capability from application-layer workflow"

require_absent "$MBEDTLS_DOC" \
  "| OCSP | ⚠️ 部分 | 需手动实现 |" \
  "MbedTLS dedicated matrix must stop classifying generic OCSP as partial support"
require_absent "$MBEDTLS_DOC" \
  "| OCSP Stapling | ❌ 不支持 | 需外部实现 |" \
  "MbedTLS dedicated matrix must stop using the vague external-implementation wording for OCSP stapling"
require_absent "$MBEDTLS_DOC" \
  "1. **OCSP Stapling**: MbedTLS 不内置 OCSP Stapling，需要应用层实现" \
  "MbedTLS limitation note must stop implying the current backend ships only an application integration gap"

echo "[PASS] MbedTLS OCSP capability doc truth contract passed"
