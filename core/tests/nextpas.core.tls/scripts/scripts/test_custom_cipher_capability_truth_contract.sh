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

require_pcre() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! python3 - "$file" "$pattern" <<'PY' >/dev/null; then
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pattern = sys.argv[2]
sys.exit(0 if re.search(pattern, text, re.S) else 1)
PY
    fail "$message"
  fi
}

base_file="src/nextpas.core.tls.base.pas"
openssl_api_ssl="src/nextpas.core.tls.openssl.api.ssl.pas"
openssl_lib="src/nextpas.core.tls.openssl.backed.pas"
openssl_ctx="src/nextpas.core.tls.openssl.context.pas"
freepascal_lib="src/nextpas.core.tls.freepascal.lib.pas"
freepascal_ctx="src/nextpas.core.tls.freepascal.context.pas"
wolfssl_lib="src/nextpas.core.tls.wolfssl.lib.pas"
wolfssl_ctx="src/nextpas.core.tls.wolfssl.context.pas"
mbedtls_lib="src/nextpas.core.tls.mbedtls.lib.pas"
mbedtls_ctx="src/nextpas.core.tls.mbedtls.context.pas"
winssl_lib="src/nextpas.core.tls.winssl.lib.pas"
winssl_ctx="src/nextpas.core.tls.winssl.context.pas"
backend_matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
api_reference="docs/reference/API_REFERENCE.md"
winssl_matrix="docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
winssl_perf="docs/reference/WINSSL_PERFORMANCE_TUNING.md"
winssl_best_practices="docs/guides/WINSSL_BEST_PRACTICES.md"
mbedtls_guide="docs/guides/MBEDTLS_USER_GUIDE.md"

echo "[TEST] custom cipher capability truth contract"

require_fixed "$base_file" "SupportsCustomCipherSuites: Boolean; // 是否支持自定义密码套件" \
  "base capability record must continue to expose SupportsCustomCipherSuites"
require_fixed "$base_file" "在调用 SetCipherList(...) / SetCipherSuites(...) 传入 custom non-default cipher override 前，先检查 ISSLLibrary.GetCapabilities.SupportsCustomCipherSuites；对 SupportsCustomCipherSuites=False 的 backend，custom non-default 赋值应抛出 unsupported，empty clear 与 shipped baseline defaults 仅作为 compatibility/default-context path。" \
  "base interface docs must record custom cipher fail-closed guidance"

require_fixed "$openssl_api_ssl" "function OpenSSLPublishedCustomCipherSurfaceReady: Boolean;" \
  "OpenSSL API surface must expose a shared published custom-cipher readiness helper"
require_fixed "$openssl_lib" "Result.SupportsCustomCipherSuites := OpenSSLPublishedCustomCipherSurfaceReady;" \
  "OpenSSL capability publication must follow runtime helper readiness"
require_pcre "$openssl_ctx" "procedure TOpenSSLContext\\.SetCipherList\\(const ACipherList: string\\);.*?if IsCustomCipherListOverride\\(ACipherList\\) then\\s+RequirePublishedOpenSSLContextCustomCipherSurface\\(" \
  "OpenSSL cipher-list setter must gate custom overrides behind the published surface"
require_pcre "$openssl_ctx" "procedure TOpenSSLContext\\.SetCipherSuites\\(const ACipherSuites: string\\);.*?if IsCustomCipherSuitesOverride\\(ACipherSuites\\) then\\s+RequirePublishedOpenSSLContextCustomCipherSurface\\(" \
  "OpenSSL cipher-suites setter must gate custom overrides behind the published surface"

require_fixed "$freepascal_lib" "Result.SupportsCustomCipherSuites := True;" \
  "FreePascal must publish custom cipher capability once runtime allowlists are parsed and applied"
require_fixed "$freepascal_ctx" "function GetConfiguredCipherSuites13: TFreePascalCipherSuiteList;" \
  "FreePascal context must expose parsed TLS 1.3 cipher-suite IDs"
require_fixed "$freepascal_ctx" "function GetConfiguredCipherSuites12: TFreePascalCipherSuiteList;" \
  "FreePascal context must expose parsed TLS 1.2 cipher-suite IDs"
require_pcre "$freepascal_ctx" "procedure TFreePascalContext\\.SetCipherList\\(const ACipherList: string\\);.*?RefreshConfiguredCipherSuites12;" \
  "FreePascal cipher-list setter must refresh parsed TLS 1.2 runtime allowlists"
require_pcre "$freepascal_ctx" "procedure TFreePascalContext\\.SetCipherSuites\\(const ACipherSuites: string\\);.*?RefreshConfiguredCipherSuites13;" \
  "FreePascal cipher-suites setter must refresh parsed TLS 1.3 runtime allowlists"

require_fixed "$wolfssl_lib" "Result.SupportsCustomCipherSuites := False;" \
  "WolfSSL must not publish custom cipher capability before runtime support exists"
require_pcre "$wolfssl_ctx" "procedure TWolfSSLContext\\.SetCipherList\\(const ACipherList: string\\);.*?if IsCustomCipherListOverride\\(ACipherList\\) then\\s+RejectUnsupportedCustomCipherAssignment\\('Cipher list', 'TWolfSSLContext\\.SetCipherList'\\);" \
  "WolfSSL cipher-list setter must reject custom non-default overrides"
require_pcre "$wolfssl_ctx" "procedure TWolfSSLContext\\.SetCipherSuites\\(const ACipherSuites: string\\);.*?if IsCustomCipherSuitesOverride\\(ACipherSuites\\) then\\s+RejectUnsupportedCustomCipherAssignment\\('Cipher suites', 'TWolfSSLContext\\.SetCipherSuites'\\);" \
  "WolfSSL cipher-suites setter must reject custom non-default overrides"

require_fixed "$mbedtls_lib" "Result.SupportsCustomCipherSuites := False;" \
  "MbedTLS must not publish custom cipher capability before runtime support exists"
require_pcre "$mbedtls_ctx" "procedure TMbedTLSContext\\.SetCipherList\\(const ACipherList: string\\);.*?if IsCustomCipherListOverride\\(ACipherList\\) then\\s+RejectUnsupportedCustomCipherAssignment\\('Cipher list', 'TMbedTLSContext\\.SetCipherList'\\);" \
  "MbedTLS cipher-list setter must reject custom non-default overrides"
require_pcre "$mbedtls_ctx" "procedure TMbedTLSContext\\.SetCipherSuites\\(const ACipherSuites: string\\);.*?if IsCustomCipherSuitesOverride\\(ACipherSuites\\) then\\s+RejectUnsupportedCustomCipherAssignment\\('Cipher suites', 'TMbedTLSContext\\.SetCipherSuites'\\);" \
  "MbedTLS cipher-suites setter must reject custom non-default overrides"

require_fixed "$winssl_lib" "Result.SupportsCustomCipherSuites := False;" \
  "WinSSL must not publish custom cipher capability before runtime support exists"
require_pcre "$winssl_ctx" "procedure TWinSSLContext\\.SetCipherList\\(const ACipherList: string\\);.*?if IsCustomCipherListOverride\\(ACipherList\\) then\\s+RejectUnsupportedCustomCipherAssignment\\('Cipher list', 'TWinSSLContext\\.SetCipherList'\\);" \
  "WinSSL cipher-list setter must reject custom non-default overrides"
require_pcre "$winssl_ctx" "procedure TWinSSLContext\\.SetCipherSuites\\(const ACipherSuites: string\\);.*?if IsCustomCipherSuitesOverride\\(ACipherSuites\\) then\\s+RejectUnsupportedCustomCipherAssignment\\('Cipher suites', 'TWinSSLContext\\.SetCipherSuites'\\);" \
  "WinSSL cipher-suites setter must reject custom non-default overrides"

require_fixed "$backend_matrix" "| **Custom Cipher Suites**      | ⚠️         | ✅      | ❌     | ❌      | ❌      |" \
  "backend capability matrix must publish current custom-cipher truth"
require_fixed "$backend_matrix" '- `OpenSSL`: `SupportsCustomCipherSuites=True` 仅在 TLS 1.2 / TLS 1.3 custom-cipher helper 都就绪时发布；custom cipher override 当前具备 runtime apply' \
  "backend matrix must record OpenSSL runtime-gated custom-cipher truth"
require_fixed "$backend_matrix" '- `FreePascal`: `SupportsCustomCipherSuites=True`；支持显式列出当前纯 Pascal runtime 已实现的 TLS 1.2 / TLS 1.3 suite allowlist，并在 ClientHello / TLS 1.2 server selection 中生效；不发布完整 OpenSSL selector/denylist 语法' \
  "backend matrix must record FreePascal explicit allowlist custom-cipher truth"
require_fixed "$backend_matrix" '- `WinSSL` / `MbedTLS` / `WolfSSL`: `SupportsCustomCipherSuites=False`；custom non-default `SetCipherList` / `SetCipherSuites` 当前会 fail-closed，empty clear / shipped baseline defaults 仅保留 compatibility/default-context path' \
  "backend matrix must record remaining false-backend fail-closed custom-cipher truth"

require_fixed "$api_reference" '在调用 `SetCipherList(...)` / `SetCipherSuites(...)` 传入 custom non-default cipher override 前，先检查 `ISSLLibrary.GetCapabilities.SupportsCustomCipherSuites`；对 `SupportsCustomCipherSuites=False` 的 backend，custom non-default 赋值应抛出 `unsupported`，empty clear 与 shipped baseline defaults 仅作为 compatibility/default-context path。' \
  "API reference must record custom cipher fail-closed guidance"
require_fixed "$winssl_matrix" '| Custom cipher configuration | ❌ 不支持 | 当前由系统 Schannel policy / Windows cipher order 决定；custom non-default `SetCipherList` / `SetCipherSuites` 会 fail-closed 为 unsupported |' \
  "WinSSL capability matrix must record current custom-cipher truth"
require_fixed "$winssl_perf" '当前 WinSSL backend 不发布 custom cipher suite override；应通过 Windows cipher order / TLS policy 调整，而不是调用 `SetCipherSuites(...)` / `SetCipherList(...)`。' \
  "WinSSL performance tuning guide must stop teaching unsupported cipher overrides"
require_absent "$winssl_perf" "LContext.SetCipherSuites(" \
  "WinSSL performance tuning guide must no longer include direct SetCipherSuites examples"
require_fixed "$winssl_best_practices" '当前 WinSSL backend 不发布 custom cipher suite override；不要把 `SetCipherSuites(...)` 当成 Schannel 调优手段。' \
  "WinSSL best-practices guide must stop teaching unsupported cipher overrides"
require_absent "$winssl_best_practices" "LContext.SetCipherSuites(" \
  "WinSSL best-practices guide must no longer include direct SetCipherSuites examples"
require_fixed "$mbedtls_guide" '当前 `SupportsCustomCipherSuites=False`：`SetCipherList` / `SetCipherSuites` 的 custom non-default assignment 会 fail-closed `unsupported`；如需安全基线，请使用 builder / default-context path。' \
  "MbedTLS guide must record current custom-cipher truth"
require_absent "$mbedtls_guide" "Context.SetCipherList(" \
  "MbedTLS guide must no longer include direct custom cipher setter examples"

echo "[PASS] custom cipher capability truth remains aligned with source/docs/runtime contract"
