#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
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

advanced_unit="core/src/nextpas.core.tls.cert.advanced.pas"
pem_unit="core/src/nextpas.core.tls.openssl.api.pem.pas"

echo "[TEST] PKCS12 helper guide active truth contract"

require_fixed "$advanced_unit" "class function CreatePKCS12ToFile(" \
  "advanced cert unit must keep CreatePKCS12ToFile helper"
require_fixed "$advanced_unit" "class function LoadFromPKCS12File(" \
  "advanced cert unit must keep LoadFromPKCS12File helper"
require_fixed "$pem_unit" "function LoadPrivateKeyFromPEM(const AFileName: string; const APassword: string = ''): PEVP_PKEY;" \
  "OpenSSL PEM helper unit must keep LoadPrivateKeyFromPEM"
require_fixed "$pem_unit" "function LoadCertificateFromPEM(const AFileName: string): PX509;" \
  "OpenSSL PEM helper unit must keep LoadCertificateFromPEM"




echo "[PASS] PKCS12 helper guide active truth contract passed"
