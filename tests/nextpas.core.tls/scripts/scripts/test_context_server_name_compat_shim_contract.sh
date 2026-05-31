#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a backend_files=(
  "src/nextpas.core.tls.openssl.connection.pas"
  "src/nextpas.core.tls.wolfssl.connection.pas"
  "src/nextpas.core.tls.freepascal.connection.pas"
  "src/nextpas.core.tls.mbedtls.connection.pas"
  "src/nextpas.core.tls.winssl.connection.pas"
)

compat_file="src/nextpas.core.tls.context.compat.pas"

if [[ -e "$compat_file" ]]; then
  echo "[FAIL] dead shared context ServerName compatibility shim should be removed: $compat_file"
  exit 1
fi

for file in "${backend_files[@]}"; do
  if grep -n -q 'GetContextLevelServerNameCompatibilityValue(' "$file"; then
    echo "[FAIL] backend still references removed context ServerName compatibility shim: $file"
    grep -n 'GetContextLevelServerNameCompatibilityValue(' "$file" || true
    exit 1
  fi

  if grep -n -E -q '(AContext|FContext)\.GetServerName' "$file"; then
    echo "[FAIL] backend still performs direct context-level ServerName fallback read: $file"
    grep -n -E '(AContext|FContext)\.GetServerName' "$file" || true
    exit 1
  fi
done

echo "[PASS] backend context ServerName dead seam is fully removed and no backend re-reads context-level fallback"
