#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a stale_checks=(
  "docs/CAPABILITY_MATRIX_GUIDE.md|\\bConn\\.SetServerName\\("
  "docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md|\\bConn\\.SetServerName\\("
  "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md|\\bConn\\.SetServerName\\("
  "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md|\\bConn1\\.SetServerName\\("
  "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md|\\bConn2\\.SetServerName\\("
)

declare -a expected_checks=(
  "docs/CAPABILITY_MATRIX_GUIDE.md|ClientConn: ISSLClientConnection;"
  "docs/CAPABILITY_MATRIX_GUIDE.md|Supports(Conn, ISSLClientConnection, ClientConn)"
  "docs/CAPABILITY_MATRIX_GUIDE.md|ClientConn.SetServerName('example.com');"
  "docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md|(Conn as ISSLClientConnection).SetServerName('example.com');"
  "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md|(Conn as ISSLClientConnection).SetServerName('example.com');"
  "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md|(Conn1 as ISSLClientConnection).SetServerName('api.example.com');"
  "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md|(Conn2 as ISSLClientConnection).SetServerName('api.example.com');"
)

for entry in "${stale_checks[@]}"; do
  file="${entry%%|*}"
  pattern="${entry#*|}"

  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] stale direct SetServerName guidance remains in $file"
    echo "       offending pattern: $pattern"
    exit 1
  fi
done

for entry in "${expected_checks[@]}"; do
  file="${entry%%|*}"
  needle="${entry#*|}"

  if ! rg -n --fixed-strings --quiet "$needle" "$file"; then
    echo "[FAIL] missing updated connection-level SNI guidance in $file"
    echo "       expected line: $needle"
    exit 1
  fi
done

echo "[PASS] capability and backend-matrix docs use explicit client-connection SNI"
