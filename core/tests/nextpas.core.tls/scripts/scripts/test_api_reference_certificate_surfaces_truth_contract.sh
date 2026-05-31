#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

doc_file="docs/reference/API_REFERENCE.md"
source_file="src/nextpas.core.tls.base.pas"

certificate_section="$(
  awk '
    /^### ISSLCertificate$/ {in_section=1}
    /^### ISSLCertificateStore$/ {in_section=0}
    in_section {print}
  ' "$doc_file"
)"

if [[ -z "$certificate_section" ]]; then
  echo "[FAIL] failed to extract ISSLCertificate section from $doc_file"
  exit 1
fi

if ! grep -F -q '### ISSLCertificateStore' "$doc_file"; then
  echo "[FAIL] active API reference still lacks a dedicated ISSLCertificateStore section"
  exit 1
fi

store_section="$(
  awk '
    /^### ISSLCertificateStore$/ {in_section=1}
    /^### ISSLConnection$/ {in_section=0}
    in_section {print}
  ' "$doc_file"
)"

if [[ -z "$store_section" ]]; then
  echo "[FAIL] failed to extract ISSLCertificateStore section from $doc_file"
  exit 1
fi

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
  if grep -F -q "$pattern" <<<"$certificate_section"; then
    echo "[FAIL] active ISSLCertificate docs still mention stale surface: $pattern"
    exit 1
  fi
done

declare -a required_certificate_patterns=(
  'function LoadFromMemory(const aData: Pointer; aSize: Integer): Boolean;'
  'function SaveToStream(aStream: TStream): Boolean;'
  'function GetInfo: TSSLCertificateInfo;'
  'function GetPublicKeyAlgorithm: string;'
  'function GetSignatureAlgorithm: string;'
  'function GetDaysUntilExpiry: Integer;'
  'function GetSubjectCN: string;'
  'function GetExtension(const aOID: string): string;'
  'function GetSubjectAltNames: TSSLStringArray;'
  'function GetKeyUsage: TSSLStringArray;'
  'function GetExtendedKeyUsage: TSSLStringArray;'
  'function GetFingerprint(aHashType: TSSLHash): string;'
  'procedure SetIssuerCertificate(aCert: ISSLCertificate);'
  'function GetIssuerCertificate: ISSLCertificate;'
  'function Clone: ISSLCertificate;'
)

for pattern in "${required_certificate_patterns[@]}"; do
  if ! grep -F -q "$pattern" <<<"$certificate_section"; then
    echo "[FAIL] active ISSLCertificate docs missing current source truth: $pattern"
    exit 1
  fi
done

declare -a required_store_patterns=(
  'ISSLCertificateStore = interface'
  'function AddCertificate(aCert: ISSLCertificate): Boolean;'
  'function RemoveCertificate(aCert: ISSLCertificate): Boolean;'
  'function Contains(aCert: ISSLCertificate): Boolean;'
  'procedure Clear;'
  'function GetCount: Integer;'
  'function GetCertificate(aIndex: Integer): ISSLCertificate;'
  'function LoadFromFile(const aFileName: string): Boolean;'
  'function LoadFromPath(const aPath: string): Boolean;'
  'function LoadSystemStore: Boolean;'
  'function FindBySubject(const aSubject: string): ISSLCertificate;'
  'function FindByIssuer(const aIssuer: string): ISSLCertificate;'
  'function FindBySerialNumber(const aSerialNumber: string): ISSLCertificate;'
  'function FindByFingerprint(const aFingerprint: string): ISSLCertificate;'
  'function VerifyCertificate(aCert: ISSLCertificate): Boolean;'
  'function BuildCertificateChain(aCert: ISSLCertificate): TSSLCertificateArray;'
)

for pattern in "${required_store_patterns[@]}"; do
  if ! grep -F -q "$pattern" <<<"$store_section"; then
    echo "[FAIL] active ISSLCertificateStore docs missing current source truth: $pattern"
    exit 1
  fi
done

echo "[PASS] active ISSLCertificate / ISSLCertificateStore docs match current source truth"
