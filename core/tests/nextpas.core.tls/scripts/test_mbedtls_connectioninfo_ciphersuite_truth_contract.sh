#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
base_file="$ROOT_DIR/src/nextpas.core.tls.mbedtls.base.pas"
api_file="$ROOT_DIR/src/nextpas.core.tls.mbedtls.api.pas"
conn_file="$ROOT_DIR/src/nextpas.core.tls.mbedtls.connection.pas"
shared_file="$ROOT_DIR/src/nextpas.core.tls.connection.base.pas"

if ! grep -F -q -- "MBEDTLS_MD_RIPEMD160 = 4;" "$base_file"; then
  echo "[FAIL] MbedTLS base constants no longer match RIPEMD160 md type truth"
  exit 1
fi

if ! grep -F -q -- "MBEDTLS_MD_SHA1 = 5;" "$base_file"; then
  echo "[FAIL] MbedTLS base constants no longer match SHA1 md type truth"
  exit 1
fi

for pattern in \
  "Pos('TLS-RSA-', LName)" \
  "Pos('AES-128-GCM', LName)" \
  "Pos('AES-256-GCM', LName)" \
  "Pos('AES-128', LName)" \
  "Pos('AES-256', LName)"
do
  if ! grep -F -q -- "$pattern" "$shared_file"; then
    echo "[FAIL] shared cipher-suite derivation no longer guards expected hyphenated MbedTLS naming pattern: $pattern"
    exit 1
  fi
done

for pattern in \
  "mbedtls_ssl_get_ciphersuite_id: Tmbedtls_ssl_get_ciphersuite_id = nil;" \
  "mbedtls_ssl_get_ciphersuite_id_from_ssl: Tmbedtls_ssl_get_ciphersuite_id_from_ssl = nil;" \
  "mbedtls_ssl_ciphersuite_from_id: Tmbedtls_ssl_ciphersuite_from_id = nil;" \
  "mbedtls_ssl_ciphersuite_get_cipher_key_bitlen: Tmbedtls_ssl_ciphersuite_get_cipher_key_bitlen = nil;"
do
  if ! grep -F -q -- "$pattern" "$api_file"; then
    echo "[FAIL] MbedTLS API is missing expected ciphersuite-info export: $pattern"
    exit 1
  fi
done

for pattern in \
  "GetProc(GMbedTLSHandle, 'mbedtls_ssl_get_ciphersuite_id')" \
  "GetProc(GMbedTLSHandle, 'mbedtls_ssl_get_ciphersuite_id_from_ssl')" \
  "GetProc(GMbedTLSHandle, 'mbedtls_ssl_ciphersuite_from_id')" \
  "GetProc(GMbedTLSHandle, 'mbedtls_ssl_ciphersuite_get_cipher_key_bitlen')"
do
  if ! grep -F -q -- "$pattern" "$api_file"; then
    echo "[FAIL] MbedTLS API no longer binds expected ciphersuite-info helper: $pattern"
    exit 1
  fi
done

if ! grep -F -q -- "Result := inherited GetConnectionInfo;" "$conn_file"; then
  echo "[FAIL] MbedTLS GetConnectionInfo no longer starts from shared connection-info truth"
  exit 1
fi

if ! grep -F -q -- "Result.CipherSuiteId := Word(LCipherSuiteId and \$FFFF);" "$conn_file"; then
  echo "[FAIL] MbedTLS GetConnectionInfo no longer writes CipherSuiteId from ciphersuite truth"
  exit 1
fi

if ! grep -F -q -- "Result.KeySize := Integer(mbedtls_ssl_ciphersuite_get_cipher_key_bitlen(LCipherSuiteInfo));" "$conn_file"; then
  echo "[FAIL] MbedTLS GetConnectionInfo no longer fills KeySize from ciphersuite truth"
  exit 1
fi

if ! grep -F -q -- "Result.MacSize := Integer(mbedtls_md_get_size(LMdInfo));" "$conn_file"; then
  echo "[FAIL] MbedTLS GetConnectionInfo no longer fills MacSize from digest truth"
  exit 1
fi

echo "[PASS] MbedTLS ciphersuite-info truth path matches the expected contract"
