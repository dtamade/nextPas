#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

file="docs/reference/API_REFERENCE.md"

expected_lservername_count=9
actual_lservername_count="$(
  { rg -o --fixed-strings "(LConn as ISSLClientConnection).SetServerName(LServerName);" "$file" || true; } | wc -l | tr -d ' '
)"

if [ "$actual_lservername_count" -ne "$expected_lservername_count" ]; then
  echo "[FAIL] unexpected count for generic connection-level SNI guidance in $file"
  echo "       expected count: $expected_lservername_count"
  echo "       actual count:   $actual_lservername_count"
  exit 1
fi

declare -a checks=(
  "(LConn1 as ISSLClientConnection).SetServerName('api.example.com');"
  "(LConn2 as ISSLClientConnection).SetServerName('api.example.com');"
)

for needle in "${checks[@]}"; do
  if ! rg -n --fixed-strings --quiet "$needle" "$file"; then
    echo "[FAIL] missing connection-level SNI guidance in $file"
    echo "       expected line: $needle"
    exit 1
  fi
done

echo "[PASS] API reference client examples teach connection-level SNI before handshake"
