#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a checks=(
  "docs/README.md|ClientConn: ISSLClientConnection;"
  "docs/README.md|ClientConn := Conn as ISSLClientConnection;"
  "docs/README.md|ClientConn.SetServerName('example.com');"
  "docs/INTEGRATION_GUIDE.md|ClientConn: ISSLClientConnection;"
  "docs/INTEGRATION_GUIDE.md|ClientConn := Conn as ISSLClientConnection;"
  "docs/INTEGRATION_GUIDE.md|ClientConn.SetServerName('example.com');"
  "docs/guides/USER_GUIDE.md|LClientConn: ISSLClientConnection;"
  "docs/guides/USER_GUIDE.md|LClientConn := LConn as ISSLClientConnection;"
  "docs/guides/USER_GUIDE.md|LClientConn.SetServerName('example.com');"
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

echo "[PASS] landing docs explicitly teach connection-level SNI in client flows"
