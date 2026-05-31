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

guide="docs/guides/security-best-practices.md"
pinning_unit="src/nextpas.core.tls.cert.pinning.pas"
pem_unit="src/nextpas.core.tls.openssl.api.pem.pas"

echo "[TEST] security best practices pinning helper truth contract"

require_fixed "$pinning_unit" "function TPinValidator.ExtractPublicKeyHash(ACert: PX509): TBytes;" \
  "pinning unit must keep the PX509-based public-key hash extractor"
require_fixed "$pem_unit" "function LoadCertificateFromPEM(const AFileName: string): PX509;" \
  "OpenSSL PEM helper unit must keep LoadCertificateFromPEM"

require_fixed "$guide" "这里走的是 OpenSSL raw certificate handle 路径，不是 backend-neutral helper。" \
  "security-best-practices must explain the raw certificate handle scope"
require_fixed "$guide" "nextpas.core.tls.openssl.api.pem," \
  "security-best-practices pinning example must import the current PEM helper unit"
require_fixed "$guide" "nextpas.core.tls.openssl.api.x509;" \
  "security-best-practices pinning example must import X509_free"
require_fixed "$guide" "Cert := LoadCertificateFromPEM('server.crt');" \
  "security-best-practices pinning example must use LoadCertificateFromPEM"
require_fixed "$guide" "if Cert <> nil then" \
  "security-best-practices pinning example must guard the X509 handle cleanup"
require_fixed "$guide" "X509_free(Cert);" \
  "security-best-practices pinning example must release the PX509 handle"

require_absent "$guide" "LoadCertificateFromFile(" \
  "security-best-practices must stop teaching nonexistent LoadCertificateFromFile"

echo "[PASS] security best practices pinning helper truth contract passed"
