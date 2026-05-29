#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

doc_file="docs/reference/API_REFERENCE.md"
source_file="src/nextpas.core.tls.base.pas"

library_section="$(
  awk '
    /^### ISSLLibrary$/ {in_section=1}
    /^### ISSLContext$/ {in_section=0}
    in_section {print}
  ' "$doc_file"
)"

context_section="$(
  awk '
    /^### ISSLContext$/ {in_section=1}
    /^### ISSLCertificate$/ {in_section=0}
    in_section {print}
  ' "$doc_file"
)"

if [[ -z "$library_section" ]]; then
  echo "[FAIL] failed to extract ISSLLibrary section from $doc_file"
  exit 1
fi

if [[ -z "$context_section" ]]; then
  echo "[FAIL] failed to extract ISSLContext section from $doc_file"
  exit 1
fi

if ! grep -F -q 'ISSLLibrary = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLLibrary in $source_file"
  exit 1
fi

if ! grep -F -q 'ISSLContext = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLContext in $source_file"
  exit 1
fi

declare -a required_library_patterns=(
  'procedure SetDefaultConfig(const aConfig: TSSLConfig);'
  'function GetDefaultConfig: TSSLConfig;'
  'function GetStatistics: TSSLStatistics;'
  'procedure ResetStatistics;'
)

for pattern in "${required_library_patterns[@]}"; do
  if ! grep -F -q "$pattern" <<<"$library_section"; then
    echo "[FAIL] active ISSLLibrary docs missing current source truth: $pattern"
    exit 1
  fi
done

declare -a required_context_patterns=(
  'procedure SetPreferredVersion(aVersion: TSSLProtocolVersion);'
  'function GetPreferredVersion: TSSLProtocolVersion;'
  'procedure LoadCertificatePEM(const aPEM: string);'
  "procedure LoadPrivateKeyPEM(const aPEM: string; const aPassword: string = '');"
  'procedure SetSessionCacheSize(aSize: Integer);'
  'function GetSessionCacheSize: Integer;'
  'procedure SetOptions(const aOptions: TSSLOptions);'
  'function GetOptions: TSSLOptions;'
  'procedure SetServerName(const aServerName: string);'
  'function GetServerName: string;'
  'procedure SetALPNProtocols(const aProtocols: string);'
  'function GetALPNProtocols: string;'
  'procedure SetCertVerifyFlags(aFlags: TSSLCertVerifyFlags);'
  'function GetCertVerifyFlags: TSSLCertVerifyFlags;'
  'procedure SetPasswordCallback(aCallback: TSSLPasswordCallback);'
  'procedure SetInfoCallback(aCallback: TSSLInfoCallback);'
  'procedure AddCertificatePin(const aHash: TBytes; aPinType: Integer;'
  'procedure AddCertificatePinBase64(const aBase64Hash: string; aPinType: Integer;'
  'procedure SetCertificatePinningEnabled(aEnabled: Boolean);'
  'function GetCertificatePinningEnabled: Boolean;'
  'procedure ClearCertificatePins;'
)

for pattern in "${required_context_patterns[@]}"; do
  if ! grep -F -q "$pattern" <<<"$context_section"; then
    echo "[FAIL] active ISSLContext docs missing current source truth: $pattern"
    exit 1
  fi
done

echo "[PASS] active ISSLLibrary / ISSLContext docs match current source truth"
