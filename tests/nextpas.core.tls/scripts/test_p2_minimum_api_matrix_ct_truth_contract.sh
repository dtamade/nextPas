#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

matrix="docs/reference/P2_MINIMUM_API_CAPABILITY_MATRIX.md"

echo "[TEST] P2 minimum API matrix CT truth contract"

require_fixed "$matrix" '- `TSSLBackendCapabilities` 已能直接表达 **PKCS12**，并部分表达 **OCSP / Store**。' \
  "P2 matrix must stop claiming CT has a direct capability-field mapping in the top summary"
require_fixed "$matrix" '| CT     | `LoadCTFunctions` + `EnableCertificateTransparency` + `ValidateSCTList` + `LoadCTLogStore` + `X509_get_SCT_LIST`' \
  "P2 matrix CT row must still list the low-level CT API set"
require_fixed "$matrix" '无默认直接字段映射；当前只代表底层 OpenSSL CT binding 可用性，不等于 OpenSSL backend 已发布 connection-level CT public surface' \
  "P2 matrix CT row must stay scoped to low-level binding availability"
require_fixed "$matrix" '`SupportsCertificateTransparency` / `CertTransparencySupport` 不应再被当成这组底层 API 的直接映射。' \
  "P2 matrix must explicitly demote CT capability fields from direct API mapping"

require_absent "$matrix" '- `TSSLBackendCapabilities` 已能直接表达 **PKCS12 / CT**，并部分表达 **OCSP / Store**。' \
  "P2 matrix must stop claiming PKCS12 and CT share the same direct-field status"

echo "[PASS] P2 minimum API matrix CT truth contract passed"
