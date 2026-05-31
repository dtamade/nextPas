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

mbedtls_lib="src/nextpas.core.tls.mbedtls.lib.pas"
wolfssl_lib="src/nextpas.core.tls.wolfssl.lib.pas"
backend_matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
faq_guide="docs/guides/FAQ.md"
pkcs12_guide="docs/guides/PKCS12_USER_GUIDE.md"
api_reference="docs/reference/API_REFERENCE.md"

echo "[TEST] optional backends PKCS12 capability truth contract"

require_fixed "$mbedtls_lib" "Result.SupportsPKCS12 := False;" \
  "MbedTLS must not publish PKCS12 capability without a shipped bundle path"
require_fixed "$wolfssl_lib" "Result.SupportsPKCS12 := False;" \
  "WolfSSL must not publish PKCS12 capability without a shipped bundle path"

require_fixed "$backend_matrix" "| **PKCS#12 / PFX**            | ❌         | ✅      | ⚠️     | ❌      | ❌      |" \
  "Backend capability matrix quick reference must record the current PKCS12 backend truth"
require_fixed "$backend_matrix" '`PKCS#12 / PFX` 这一行按当前 published/runtime truth 汇总：' \
  "Backend capability matrix must explain PKCS12 row semantics"
require_fixed "$backend_matrix" '- `OpenSSL`: `SupportsPKCS12=True`；当前发布完整 PKCS#12 helper/API surface（create / parse / BIO I/O）' \
  "Backend capability matrix must record full OpenSSL PKCS12 publication"
require_fixed "$backend_matrix" '- `WinSSL`: `SupportsPKCS12=True`；当前仅发布 PFX/P12 private-key/certificate bundle import path' \
  "Backend capability matrix must record partial WinSSL PKCS12 publication"
require_fixed "$backend_matrix" '- `FreePascal` / `MbedTLS` / `WolfSSL`: `SupportsPKCS12=False`；当前没有 shipped PKCS#12 bundle create / parse / import surface' \
  "Backend capability matrix must record unsupported PKCS12 backends"

require_fixed "$faq_guide" "**A**: 支持，但当前是 backend-specific：" \
  "FAQ must stop claiming PKCS12 is only planned"
require_fixed "$faq_guide" '- `OpenSSL`: 提供完整 PKCS#12 helper/API surface（创建、解析、BIO I/O）' \
  "FAQ must mention full OpenSSL PKCS12 support"
require_fixed "$faq_guide" '- `WinSSL`: 当前仅发布 PFX/P12 import path（用于加载证书+私钥 bundle）' \
  "FAQ must mention partial WinSSL PKCS12 support"
require_fixed "$faq_guide" '- `FreePascal` / `MbedTLS` / `WolfSSL`: 当前不发布 PKCS#12 bundle surface' \
  "FAQ must mention unsupported PKCS12 backends"
require_absent "$faq_guide" "**A**: 当前版本专注于PEM/DER，PKCS#12支持计划中。" \
  "FAQ must stop claiming PKCS12 is only planned"

require_fixed "$pkcs12_guide" "本指南讨论的是 OpenSSL backend 暴露的 PKCS#12 helper/API surface，不代表所有 backend 都发布同等能力。" \
  "PKCS12 guide must clarify its OpenSSL-only scope"
require_fixed "$pkcs12_guide" '- `OpenSSL`: 提供完整 PKCS#12 helper/API surface' \
  "PKCS12 guide must state OpenSSL full support"
require_fixed "$pkcs12_guide" '- `WinSSL`: 仅发布 PFX/P12 import path，不提供本指南中的 helper/API surface' \
  "PKCS12 guide must state WinSSL partial support"
require_fixed "$pkcs12_guide" '- `FreePascal` / `MbedTLS` / `WolfSSL`: 当前不发布 PKCS#12 bundle create / parse / import surface' \
  "PKCS12 guide must state unsupported PKCS12 backends"

require_fixed "$api_reference" '当前 `SupportsPKCS12` 的 published truth 为：`OpenSSL`=完整 PKCS#12 helper/API，`WinSSL`=PFX/P12 bundle import，`FreePascal` / `MbedTLS` / `WolfSSL`=不发布 PKCS#12 bundle surface。' \
  "API reference must record the current global PKCS12 truth"

echo "[PASS] optional backends PKCS12 capability truth contract passed"
