#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.winssl.base.pas"
conn_file="src/nextpas.core.tls.winssl.connection.pas"

if ! grep -F -q -- "SECPKG_ATTR_CIPHER_INFO        = 100;" "$base_file"; then
  echo "[FAIL] WinSSL base is missing SECPKG_ATTR_CIPHER_INFO"
  exit 1
fi

if ! grep -F -q -- "QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_CIPHER_INFO," "$conn_file"; then
  echo "[FAIL] WinSSL connection info no longer queries SECPKG_ATTR_CIPHER_INFO"
  exit 1
fi

if grep -F -q -- "Result.CipherSuiteId := Word(ConnInfo.aiCipher);" "$conn_file"; then
  echo "[FAIL] WinSSL GetConnectionInfo still maps ConnInfo.aiCipher directly into CipherSuiteId"
  exit 1
fi

if ! grep -F -q -- "Result.CipherSuiteId := CipherSuiteId;" "$conn_file"; then
  echo "[FAIL] WinSSL GetConnectionInfo no longer writes CipherSuiteId from cipher-info truth"
  exit 1
fi

echo "[PASS] WinSSL GetConnectionInfo cipher truth matches the expected Schannel path"
