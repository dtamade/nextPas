#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

ssl_api_file="src/nextpas.core.tls.openssl.api.ssl.pas"
evp_api_file="src/nextpas.core.tls.openssl.api.evp.pas"
conn_file="src/nextpas.core.tls.openssl.connection.pas"

if ! grep -F -q -- "SSL_CIPHER_get_digest_nid: TSSL_CIPHER_get_digest_nid;" "$ssl_api_file"; then
  echo "[FAIL] OpenSSL SSL API is missing SSL_CIPHER_get_digest_nid export"
  exit 1
fi

if ! grep -F -q -- "SSL_CIPHER_is_aead: TSSL_CIPHER_is_aead;" "$ssl_api_file"; then
  echo "[FAIL] OpenSSL SSL API is missing SSL_CIPHER_is_aead export"
  exit 1
fi

if ! grep -F -q -- "GetSSLProcAddress('SSL_CIPHER_get_digest_nid')" "$ssl_api_file"; then
  echo "[FAIL] OpenSSL SSL API no longer binds SSL_CIPHER_get_digest_nid"
  exit 1
fi

if ! grep -F -q -- "GetSSLProcAddress('SSL_CIPHER_is_aead')" "$ssl_api_file"; then
  echo "[FAIL] OpenSSL SSL API no longer binds SSL_CIPHER_is_aead"
  exit 1
fi

if ! grep -F -q -- "EVP_get_digestbynid: TEVP_get_digestbynid = nil;" "$evp_api_file"; then
  echo "[FAIL] OpenSSL EVP API is missing EVP_get_digestbynid export"
  exit 1
fi

if ! grep -F -q -- "(Name: 'EVP_get_digestbynid'; FuncPtr: @EVP_get_digestbynid; Required: False)," "$evp_api_file"; then
  echo "[FAIL] OpenSSL EVP API no longer binds EVP_get_digestbynid"
  exit 1
fi

if ! grep -F -q -- "Assigned(SSL_CIPHER_is_aead)" "$conn_file"; then
  echo "[FAIL] OpenSSL connection info no longer guards legacy MacSize with SSL_CIPHER_is_aead"
  exit 1
fi

if ! grep -F -q -- "DigestMd := EVP_get_digestbynid(DigestNid);" "$conn_file"; then
  echo "[FAIL] OpenSSL connection info no longer resolves digest truth for MacSize"
  exit 1
fi

if ! grep -F -q -- "Result.MacSize := EVP_MD_size(DigestMd);" "$conn_file"; then
  echo "[FAIL] OpenSSL connection info no longer writes MacSize from digest truth"
  exit 1
fi

echo "[PASS] OpenSSL MacSize truth path matches the expected low-level digest contract"
