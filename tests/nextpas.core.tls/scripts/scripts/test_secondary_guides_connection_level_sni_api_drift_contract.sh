#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a stale_checks=(
  "docs/guides/QUICKSTART.md|Conn1.SetServerName("
  "docs/guides/QUICKSTART.md|Conn2.SetServerName("
  "docs/guides/QUICKSTART.md|Conn.SetServerName("
  "docs/guides/COMMON_PITFALLS.md|Conn.SetServerName("
  "docs/guides/PERFORMANCE_PROFILING_GUIDE.md|Conn.SetServerName("
  "docs/guides/WINSSL_BEST_PRACTICES.md|LConn.SetServerName("
)

declare -a expected_checks=(
  "docs/guides/QUICKSTART.md|(Conn1 as ISSLClientConnection).SetServerName('api.example.com');"
  "docs/guides/QUICKSTART.md|(Conn2 as ISSLClientConnection).SetServerName('api.example.com');"
  "docs/guides/QUICKSTART.md|(Conn as ISSLClientConnection).SetServerName(Host);"
  "docs/guides/COMMON_PITFALLS.md|(Conn as ISSLClientConnection).SetServerName('api.example.com');"
  "docs/guides/PERFORMANCE_PROFILING_GUIDE.md|(Conn as ISSLClientConnection).SetServerName(Host);"
  "docs/guides/WINSSL_BEST_PRACTICES.md|(LConn as ISSLClientConnection).SetServerName('example.com');"
)

for entry in "${stale_checks[@]}"; do
  file="${entry%%|*}"
  needle="${entry#*|}"

  if rg -n --fixed-strings --quiet "$needle" "$file"; then
    echo "[FAIL] stale direct SetServerName guidance remains in $file"
    echo "       offending line contains: $needle"
    exit 1
  fi
done

for entry in "${expected_checks[@]}"; do
  file="${entry%%|*}"
  needle="${entry#*|}"

  if ! rg -n --fixed-strings --quiet "$needle" "$file"; then
    echo "[FAIL] missing explicit client-connection SNI guidance in $file"
    echo "       expected line: $needle"
    exit 1
  fi
done

echo "[PASS] selected secondary guides use explicit client-connection SNI"
