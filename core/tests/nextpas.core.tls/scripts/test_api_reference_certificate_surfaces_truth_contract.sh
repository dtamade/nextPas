#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="core/src/nextpas.core.tls.base.pas"






if ! grep -F -q 'ISSLCertificate = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLCertificate in $source_file"
  exit 1
fi

if ! grep -F -q 'ISSLCertificateStore = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLCertificateStore in $source_file"
  exit 1
fi

declare -a forbidden_certificate_patterns=(
  'function GetSubjectAltNames: TStringList;'
  'function GetKeyUsage: TStringList;'
  'function GetExtendedKeyUsage: TStringList;'
)

for pattern in "${forbidden_certificate_patterns[@]}"; do
  if grep -F -q "$pattern" "$source_file"; then
    echo "[FAIL] active ISSLCertificate source surface still declares stale: $pattern"
    exit 1
  fi
done

declare -a required_certificate_patterns=(
  'function LoadFromMemory'
  'function SaveToStream'
  'function GetInfo'
  'function GetPublicKeyAlgorithm'
  'function GetSignatureAlgorithm'
  'function GetDaysUntilExpiry'
  'function GetSubjectCN'
  'function GetExtension'
  'function GetSubjectAltNames'
  'function GetKeyUsage'
  'function GetExtendedKeyUsage'
  'function GetFingerprint'
  'procedure SetIssuerCertificate'
  'function GetIssuerCertificate'
  'function Clone'
)

for pattern in "${required_certificate_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$source_file"; then
    echo "[FAIL] active ISSLCertificate source surface missing current truth: $pattern"
    exit 1
  fi
done

declare -a required_store_patterns=(
  'ISSLCertificateStore = interface'
  'function AddCertificate'
  'function RemoveCertificate'
  'function Contains'
  'procedure Clear'
  'function GetCount'
  'function GetCertificate'
  'function LoadFromFile'
  'function LoadFromPath'
  'function LoadSystemStore'
  'function FindBySubject'
  'function FindByIssuer'
  'function FindBySerialNumber'
  'function FindByFingerprint'
  'function VerifyCertificate'
  'function BuildCertificateChain'
)

for pattern in "${required_store_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$source_file"; then
    echo "[FAIL] active ISSLCertificateStore source surface missing current truth: $pattern"
    exit 1
  fi
done

echo "[PASS] ISSLCertificate / ISSLCertificateStore source surface matches current truth"
