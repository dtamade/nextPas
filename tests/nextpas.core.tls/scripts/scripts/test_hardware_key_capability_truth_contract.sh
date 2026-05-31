#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
openssl_ctx="$root_dir/src/nextpas.core.tls.openssl.context.pas"
openssl_lib="$root_dir/src/nextpas.core.tls.openssl.backed.pas"
backend_matrix_doc="$root_dir/docs/BACKEND_CAPABILITY_MATRIX.md"
winssl_lib="$root_dir/src/nextpas.core.tls.winssl.lib.pas"
winssl_doc="$root_dir/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_present() {
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

require_present "$openssl_ctx" "procedure TOpenSSLContext.LoadPrivateKeyFromPKCS11" \
  "OpenSSL context no longer exposes the shipped LoadPrivateKeyFromPKCS11 path"
require_present "$openssl_ctx" "Backend := TPKCS11BackendFactory.CreateBackend(btAuto);" \
  "OpenSSL PKCS#11 loader no longer routes through the shipped PKCS#11 backend factory"

require_present "$openssl_lib" "LPKCS11Ready := TPKCS11BackendFactory.IsBackendAvailable(btAuto);" \
  "OpenSSL capability truth no longer derives PKCS#11 from runtime backend readiness"
require_present "$openssl_lib" "Result.SupportsPKCS11 := LPKCS11Ready;" \
  "OpenSSL capability truth no longer publishes runtime-aware PKCS#11 support"
require_absent "$openssl_lib" "Result.SupportsPKCS11 := True;" \
  "OpenSSL capability truth regressed to unconditional PKCS#11 support"
require_present "$openssl_lib" "Result.SupportsTPM := False;" \
  "OpenSSL capability truth still advertises TPM without a shipped public/runtime path"

require_present "$backend_matrix_doc" '当前 capability truth 跟随 `TPKCS11BackendFactory.IsBackendAvailable(btAuto)`' \
  "OpenSSL active capability doc no longer records runtime-aware PKCS#11 truth"
require_present "$backend_matrix_doc" '但若当前 OpenSSL 运行时缺少 Provider / ENGINE 必需 surface，`SupportsPKCS11` 会降为 `False`' \
  "OpenSSL active capability doc no longer records PKCS#11 fail-closed runtime behavior"

require_present "$winssl_lib" "Result.SupportsPKCS11 := False;" \
  "WinSSL capability truth still advertises PKCS#11 without a shipped public/runtime path"
require_present "$winssl_lib" "Result.SupportsTPM := False;" \
  "WinSSL capability truth still advertises TPM without a shipped public/runtime path"

require_absent "$winssl_doc" "| 智能卡 | ✅ 支持 | 原生支持 |" \
  "WinSSL capability doc still claims smart-card support as a published backend capability"
require_absent "$winssl_doc" "| TPM | ✅ 支持 | 硬件密钥 |" \
  "WinSSL capability doc still claims TPM support as a published backend capability"
require_absent "$winssl_doc" "原生支持智能卡和 TPM" \
  "WinSSL capability doc still markets hardware-key support as a published backend advantage"

require_present "$winssl_doc" "| 智能卡 / PKCS#11                | ❌ 当前 capability 不发布 |" \
  "WinSSL capability doc no longer records the current non-published smart-card/PKCS#11 truth"
require_present "$winssl_doc" "| TPM                             | ❌ 当前 capability 不发布 |" \
  "WinSSL capability doc no longer records the current non-published TPM truth"

echo "[PASS] hardware-key capability truth remains aligned with shipped source and active backend docs"
