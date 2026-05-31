#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
source_file="$repo_root/src/nextpas.core.tls.base.pas"
doc_file="$repo_root/docs/guides/TROUBLESHOOTING.md"
test_file="$repo_root/tests/certificate/test_certificate_unit.pas"

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if ! grep -F -q "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

forbid_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -F -q "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "$source_file" "SubjectAltNames: TSSLStringArray;" \
  "TSSLCertificateInfo.SubjectAltNames must stay a TSSLStringArray snapshot"
require_fixed "$source_file" "function GetSubjectAltNames: TSSLStringArray;" \
  "ISSLCertificate.GetSubjectAltNames must stay array-based"
require_fixed "$source_file" "function GetKeyUsage: TSSLStringArray;" \
  "ISSLCertificate.GetKeyUsage must stay array-based"
require_fixed "$source_file" "function GetExtendedKeyUsage: TSSLStringArray;" \
  "ISSLCertificate.GetExtendedKeyUsage must stay array-based"

forbid_fixed "$doc_file" "LAltNames.Count" \
  "Troubleshooting guide must not teach list Count on GetSubjectAltNames"
forbid_fixed "$doc_file" "LAltNames.Free" \
  "Troubleshooting guide must not teach manual Free on GetSubjectAltNames"
require_fixed "$doc_file" "if Length(LAltNames) > 0 then" \
  "Troubleshooting guide must show Length-based SAN handling"
require_fixed "$doc_file" "for var i := 0 to High(LAltNames) do" \
  "Troubleshooting guide must iterate SAN arrays with High(...)"

forbid_fixed "$test_file" "KeyUsageList: TStringList;" \
  "test_certificate_unit must not treat key-usage arrays as TStringList"
forbid_fixed "$test_file" "SANs, KeyUsage: TStringList;" \
  "test_certificate_unit must not treat SAN/key-usage arrays as TStringList"
forbid_fixed "$test_file" "with Cert.GetSubjectAltNames do" \
  "test_certificate_unit must not use list-style SAN array iteration"
forbid_fixed "$test_file" "SANs.IndexOf(" \
  "test_certificate_unit must not use TStringList IndexOf on SAN arrays"
forbid_fixed "$test_file" "SANs.Free;" \
  "test_certificate_unit must not free SAN arrays"
forbid_fixed "$test_file" "KeyUsage.Free;" \
  "test_certificate_unit must not free key-usage arrays"
require_fixed "$test_file" "function ArrayContains(const AValues: TSSLStringArray; const AExpected: string): Boolean;" \
  "test_certificate_unit should use array helper for SAN membership"

echo "[PASS] certificate public SAN array semantics contract is satisfied."
