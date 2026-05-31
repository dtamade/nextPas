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

guide="docs/guides/PKCS12_USER_GUIDE.md"
api_reference="docs/reference/API_REFERENCE.md"
facade="src/nextpas.core.tls.pas"
advanced_unit="src/nextpas.core.tls.cert.advanced.pas"
pem_unit="src/nextpas.core.tls.openssl.api.pem.pas"

echo "[TEST] PKCS12 helper guide active truth contract"

require_fixed "$facade" "TPKCS12Manager = nextpas.core.tls.cert.advanced.TPKCS12Manager;" \
  "facade must continue to re-export TPKCS12Manager"
require_fixed "$facade" "function DefaultPKCS12Options: TPKCS12Options;" \
  "facade must continue to expose DefaultPKCS12Options"
require_fixed "$advanced_unit" "class function CreatePKCS12ToFile(" \
  "advanced cert unit must keep CreatePKCS12ToFile helper"
require_fixed "$advanced_unit" "class function LoadFromPKCS12File(" \
  "advanced cert unit must keep LoadFromPKCS12File helper"
require_fixed "$pem_unit" "function LoadPrivateKeyFromPEM(const AFileName: string; const APassword: string = ''): PEVP_PKEY;" \
  "OpenSSL PEM helper unit must keep LoadPrivateKeyFromPEM"
require_fixed "$pem_unit" "function LoadCertificateFromPEM(const AFileName: string): PX509;" \
  "OpenSSL PEM helper unit must keep LoadCertificateFromPEM"

require_fixed "$guide" "推荐入口分两层：" \
  "PKCS12 guide must explicitly distinguish helper-vs-raw entrypoints"
require_fixed "$guide" '- 高入口 helper：`fafafa.ssl` / `TPKCS12Manager` / `DefaultPKCS12Options`' \
  "PKCS12 guide must publish the high-level helper entrypoint"
require_fixed "$guide" '- OpenSSL raw API：`nextpas.core.tls.openssl.api.pkcs12` + `nextpas.core.tls.openssl.api.pem`' \
  "PKCS12 guide must publish the raw OpenSSL API entrypoint"
require_fixed "$guide" "TPKCS12Manager.CreatePKCS12ToFile(" \
  "PKCS12 guide must use CreatePKCS12ToFile in active helper examples"
require_fixed "$guide" "TPKCS12Manager.LoadFromPKCS12File(" \
  "PKCS12 guide must use LoadFromPKCS12File in active helper examples"
require_fixed "$guide" "LoadCertificateFromPEM('cert.pem');" \
  "PKCS12 guide raw example must use current LoadCertificateFromPEM helper"
require_fixed "$guide" "LoadPrivateKeyFromPEM('key.pem', '');" \
  "PKCS12 guide raw example must use current LoadPrivateKeyFromPEM helper"

require_absent "$guide" "LoadCertificateFromFile(" \
  "PKCS12 guide must stop using nonexistent LoadCertificateFromFile"
require_absent "$guide" "LoadPrivateKeyFromFile(" \
  "PKCS12 guide must stop using nonexistent LoadPrivateKeyFromFile"

require_fixed "$api_reference" "### PKCS#12 Helper" \
  "API reference must expose a PKCS12 helper section"
require_fixed "$api_reference" "function DefaultPKCS12Options: TPKCS12Options;" \
  "API reference must list DefaultPKCS12Options"
require_fixed "$api_reference" "class function TPKCS12Manager.CreatePKCS12(" \
  "API reference must list CreatePKCS12"
require_fixed "$api_reference" "class function TPKCS12Manager.CreatePKCS12ToFile(" \
  "API reference must list CreatePKCS12ToFile"
require_fixed "$api_reference" "class function TPKCS12Manager.LoadFromPKCS12File(" \
  "API reference must list LoadFromPKCS12File"
require_fixed "$api_reference" '这组 helper 当前对应 `OpenSSL` 的完整 PKCS#12 helper/API surface；`WinSSL` 仅发布 PFX/P12 import path，不提供这里的 helper 族。' \
  "API reference must explain the PKCS12 helper backend boundary"

echo "[PASS] PKCS12 helper guide active truth contract passed"
