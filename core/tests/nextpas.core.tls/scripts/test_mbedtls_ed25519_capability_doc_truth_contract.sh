#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MBEDTLS_LIB="$ROOT_DIR/core/src/nextpas.core.tls.mbedtls.lib.pas"
ASN1_FILE="$ROOT_DIR/core/src/nextpas.core.crypto.asn1.pas"
X509_FILE="$ROOT_DIR/core/src/nextpas.core.tls.x509.pas"

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

echo "[PASS] MbedTLS Ed25519 capability doc truth contract passed"
