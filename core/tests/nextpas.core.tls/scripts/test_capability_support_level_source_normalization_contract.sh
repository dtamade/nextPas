#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a backend_files=(
  "src/nextpas.core.tls.openssl.backed.pas"
  "src/nextpas.core.tls.freepascal.lib.pas"
  "src/nextpas.core.tls.winssl.lib.pas"
  "src/nextpas.core.tls.mbedtls.lib.pas"
  "src/nextpas.core.tls.wolfssl.lib.pas"
)

declare -a legacy_fields=(
  "SupportsSNI"
  "SupportsALPN"
  "SupportsOCSPStapling"
  "SupportsCertificateTransparency"
  "SupportsSessionTickets"
)

for file in "${backend_files[@]}"; do
  if ! grep -n -q 'NormalizeLegacyCapabilityBooleans(Result);' "$file"; then
    echo "[FAIL] backend GetCapabilities no longer shares legacy bool projection helper: $file"
    exit 1
  fi

  for field in "${legacy_fields[@]}"; do
    if grep -n -q "Result\\.${field} :=" "$file"; then
      echo "[FAIL] backend still assigns paired legacy capability bool directly: $file -> $field"
      grep -n "Result\\.${field} :=" "$file"
      exit 1
    fi
  done
done

echo "[PASS] backend capability sources publish support-level truth and derive paired legacy booleans via normalization"
