#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

winssl_file="src/nextpas.core.tls.winssl.connection.pas"
mbedtls_file="src/nextpas.core.tls.mbedtls.connection.pas"
openssl_file="src/nextpas.core.tls.openssl.connection.pas"
wolfssl_file="src/nextpas.core.tls.wolfssl.connection.pas"
freepascal_file="src/nextpas.core.tls.freepascal.connection.pas"

winssl_setsession_body="$(sed -n '/^procedure TWinSSLConnection.DoSetSession/,/^end;$/p' "$winssl_file")"
mbedtls_setsession_body="$(sed -n '/^procedure TMbedTLSConnection.DoSetSession/,/^end;$/p' "$mbedtls_file")"
openssl_isreused_body="$(sed -n '/^function TOpenSSLConnection.DoIsSessionReused/,/^end;$/p' "$openssl_file")"
wolfssl_isreused_body="$(sed -n '/^function TWolfSSLConnection.DoIsSessionReused/,/^end;$/p' "$wolfssl_file")"
freepascal_setsession_body="$(sed -n '/^procedure TFreePascalConnection.DoSetSession/,/^end;$/p' "$freepascal_file")"

if grep -F -q 'FSessionReused := True' <<<"$winssl_setsession_body"; then
  echo "[FAIL] WinSSL DoSetSession still preclaims session reuse before handshake truth exists"
  exit 1
fi

if ! grep -F -q 'FCurrentSession := ASession;' <<<"$winssl_setsession_body"; then
  echo "[FAIL] WinSSL DoSetSession no longer stores the configured/current session"
  exit 1
fi

if grep -F -q 'FSessionReused := True' <<<"$mbedtls_setsession_body"; then
  echo "[FAIL] MbedTLS DoSetSession still preclaims session reuse before handshake truth exists"
  exit 1
fi

if ! grep -F -q 'mbedtls_ssl_set_session' <<<"$mbedtls_setsession_body"; then
  echo "[FAIL] MbedTLS DoSetSession no longer attempts native session configuration"
  exit 1
fi

if ! grep -F -q 'SSL_session_reused' <<<"$openssl_isreused_body"; then
  echo "[FAIL] OpenSSL DoIsSessionReused no longer reads native SSL_session_reused truth"
  exit 1
fi

if ! grep -F -q 'wolfSSL_session_reused' <<<"$wolfssl_isreused_body"; then
  echo "[FAIL] WolfSSL DoIsSessionReused no longer reads native wolfSSL_session_reused truth"
  exit 1
fi

if ! grep -F -q 'FSessionReused := False;' <<<"$freepascal_setsession_body"; then
  echo "[FAIL] FreePascal DoSetSession no longer clears reuse state before the next handshake"
  exit 1
fi

echo "[PASS] session reused semantics still distinguish configured session from actual resumed handshake"
