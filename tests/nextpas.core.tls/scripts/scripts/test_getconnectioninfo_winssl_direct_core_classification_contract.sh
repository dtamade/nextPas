#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -A expected_files=(
  ["tests/winssl/test_winssl_connection_info.pas"]="INTENTIONAL_CORE_SURFACE"
  ["tests/winssl/test_winssl_connection_edge_cases.pas"]="INTENTIONAL_CORE_SURFACE"
)

pattern='\b(?:Conn|LConn|LConnection)\.GetConnectionInfo\b'

for file in "${!expected_files[@]}"; do
  marker="${expected_files[$file]}"

  if ! rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] expected WinSSL direct-core GetConnectionInfo proof is missing: $file"
    exit 1
  fi

  if ! rg -n --quiet "$marker" "$file"; then
    echo "[FAIL] missing $marker classification in $file"
    exit 1
  fi
done

mapfile -t winssl_hit_files < <(rg -l "$pattern" tests/winssl || true)

for file in "${winssl_hit_files[@]}"; do
  if [[ -z "${expected_files[$file]+x}" ]]; then
    echo "[FAIL] unexpected WinSSL direct-core GetConnectionInfo surface remains: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] WinSSL residual direct-core GetConnectionInfo tests are explicitly classified"
