#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a checks=(
  "docs/guides/ERROR_HANDLING_BEST_PRACTICES.md|LHost: string;"
  "docs/guides/ERROR_HANDLING_BEST_PRACTICES.md|LHost := 'api.example.com';"
  "docs/guides/ERROR_HANDLING_BEST_PRACTICES.md|(LConnection as ISSLClientConnection).SetServerName(LHost);"
)

for entry in "${checks[@]}"; do
  file="${entry%%|*}"
  needle="${entry#*|}"

  if ! rg -n --fixed-strings --quiet "$needle" "$file"; then
    echo "[FAIL] missing URL-driven connection-level SNI guidance in $file"
    echo "       expected line: $needle"
    exit 1
  fi
done

echo "[PASS] error-handling guide teaches URL-driven connection-level SNI before handshake"
