#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MBEDTLS_LIB="$ROOT_DIR/src/nextpas.core.tls.mbedtls.lib.pas"
ASN1_FILE="$ROOT_DIR/src/nextpas.core.tls.asn1.pas"
X509_FILE="$ROOT_DIR/src/nextpas.core.tls.x509.pas"
MBEDTLS_DOC="$ROOT_DIR/docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md"

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

echo "[TEST] MbedTLS Ed25519 capability doc truth contract"

require_fixed "$MBEDTLS_LIB" \
  "sslKexRSA, sslKexDHE_RSA, sslKexECDHE_RSA, sslKexECDHE_ECDSA" \
  "MbedTLS capability record must keep the current shipped key-exchange families"
require_fixed "$ASN1_FILE" \
  "(OID: '1.3.101.112';           Name: 'Ed25519')" \
  "ASN.1 OID table must expose Ed25519 by name"
require_fixed "$X509_FILE" \
  "'1.3.101.112':  // Ed25519" \
  "X509 parser must recognize Ed25519 public-key OID"
require_fixed "$X509_FILE" \
  "FPublicKeyInfo.KeyType := 'Ed25519';" \
  "X509 parser must expose Ed25519 key type truth"
require_fixed "$X509_FILE" \
  "FPublicKeyInfo.KeySize := Length(FPublicKeyInfo.PublicKey) * 8;" \
  "X509 parser must derive Edwards public-key size from parsed key bytes"
require_fixed "$MBEDTLS_DOC" \
  '| Ed25519 | ❌ 当前握手 capability 不发布 | 当前 backend 仍未发布 Ed25519-specific key-exchange / capability signals；但在加载 Ed25519 证书时，parser-backed certificate metadata 已能暴露 `Ed25519` 算法名与 256-bit 公钥大小；不要把这条 certificate metadata truth 误当成完整握手能力声明 |' \
  "MbedTLS dedicated matrix must distinguish Ed25519 certificate metadata truth from handshake capability truth"
require_absent "$MBEDTLS_DOC" \
  "| Ed25519 | ⚠️ 部分 | MbedTLS 3.x |" \
  "MbedTLS dedicated matrix must stop describing Ed25519 as partial support"
require_absent "$MBEDTLS_DOC" \
  "当前仍返回 RSA 默认值" \
  "MbedTLS dedicated matrix must stop freezing the old RSA-default Ed25519 story"

echo "[PASS] MbedTLS Ed25519 capability doc truth contract passed"
