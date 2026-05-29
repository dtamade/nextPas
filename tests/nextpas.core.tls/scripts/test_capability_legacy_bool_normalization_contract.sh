#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"

if ! grep -n -q 'procedure NormalizeLegacyCapabilityBooleans(var ACaps: TSSLBackendCapabilities);' "$base_file"; then
  echo "[FAIL] missing shared NormalizeLegacyCapabilityBooleans helper declaration in $base_file"
  exit 1
fi

declare -a backend_files=(
  "src/nextpas.core.tls.openssl.backed.pas"
  "src/nextpas.core.tls.freepascal.lib.pas"
  "src/nextpas.core.tls.winssl.lib.pas"
  "src/nextpas.core.tls.mbedtls.lib.pas"
  "src/nextpas.core.tls.wolfssl.lib.pas"
)

for file in "${backend_files[@]}"; do
  if ! grep -n -q 'NormalizeLegacyCapabilityBooleans(Result);' "$file"; then
    echo "[FAIL] backend GetCapabilities does not normalize legacy boolean truth: $file"
    exit 1
  fi
done

echo "[PASS] backend capability sources share legacy boolean normalization"
