#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a checks=(
  "docs/guides/MIGRATION_GUIDE.md|(LConn as ISSLClientConnection).SetServerName('example.com');"
  "docs/guides/TROUBLESHOOTING.md|(LConn1 as ISSLClientConnection).SetServerName('example.com');"
  "docs/guides/TROUBLESHOOTING.md|(LConn2 as ISSLClientConnection).SetServerName('example.com');"
)

for entry in "${checks[@]}"; do
  file="${entry%%|*}"
  needle="${entry#*|}"

  if ! rg -n --fixed-strings --quiet "$needle" "$file"; then
    echo "[FAIL] missing connection-level SNI guidance in $file"
    echo "       expected line: $needle"
    exit 1
  fi
done

echo "[PASS] migration and troubleshooting guides teach connection-level SNI in selected client flows"
