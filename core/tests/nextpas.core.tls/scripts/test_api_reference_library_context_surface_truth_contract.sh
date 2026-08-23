#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="core/src/nextpas.core.tls.base.pas"





if ! grep -F -q 'ISSLLibrary = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLLibrary in $source_file"
  exit 1
fi

if ! grep -F -q 'ISSLContext = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLContext in $source_file"
  exit 1
fi

declare -a required_library_patterns=(
  'procedure SetDefaultConfig'
  'function GetDefaultConfig'
  'function GetStatistics'
  'procedure ResetStatistics'
)

for pattern in "${required_library_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$source_file"; then
    echo "[FAIL] active ISSLLibrary source surface missing current truth: $pattern"
    exit 1
  fi
done

declare -a required_context_patterns=(
  'procedure SetPreferredVersion'
  'function GetPreferredVersion'
  'procedure LoadCertificatePEM'
  'procedure LoadPrivateKeyPEM'
  'procedure SetSessionCacheSize'
  'function GetSessionCacheSize'
  'procedure SetOptions'
  'function GetOptions'
  'procedure SetServerName'
  'function GetServerName'
  'procedure SetALPNProtocols'
  'function GetALPNProtocols'
  'procedure SetCertVerifyFlags'
  'function GetCertVerifyFlags'
  'procedure SetPasswordCallback'
  'procedure SetInfoCallback'
  'procedure AddCertificatePin'
  'procedure AddCertificatePinBase64('
  'procedure SetCertificatePinningEnabled'
  'function GetCertificatePinningEnabled'
  'procedure ClearCertificatePins'
)

for pattern in "${required_context_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$source_file"; then
    echo "[FAIL] active ISSLContext source surface missing current truth: $pattern"
    exit 1
  fi
done

echo "[PASS] active ISSLLibrary / ISSLContext docs match current source truth"
