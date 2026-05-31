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
freepascal_lib="src/nextpas.core.tls.freepascal.lib.pas"
freepascal_ctx="src/nextpas.core.tls.freepascal.context.pas"
wolfssl_lib="src/nextpas.core.tls.wolfssl.lib.pas"
wolfssl_ctx="src/nextpas.core.tls.wolfssl.context.pas"
mbedtls_lib="src/nextpas.core.tls.mbedtls.lib.pas"
winssl_lib="src/nextpas.core.tls.winssl.lib.pas"
backend_matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
api_reference="docs/reference/API_REFERENCE.md"
winssl_matrix="docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"

echo "[TEST] password-protected key capability truth contract"

require_fixed "$base_file" "SupportsPasswordProtectedKeys: Boolean; // 加密私钥支持" \
  "base capability record must continue to expose SupportsPasswordProtectedKeys"
require_fixed "$base_file" "在向 LoadPrivateKey(..., APassword) / LoadPrivateKeyPEM(..., APassword) 传入非空密码前，先检查 ISSLLibrary.GetCapabilities.SupportsPasswordProtectedKeys；对 SupportsPasswordProtectedKeys=False 的 backend，non-empty APassword 应抛出 unsupported，而不是 silent ignore。" \
  "base interface docs must record password-protected key fail-closed guidance"

require_fixed "$freepascal_lib" "Result.SupportsPasswordProtectedKeys := False;" \
  "FreePascal must not publish password-protected key capability before runtime support exists"
require_pcre "$freepascal_ctx" "procedure TFreePascalContext\\.LoadPrivateKey\\(const AFileName: string; const APassword: string\\);.*?if APassword <> '' then\\s+RejectUnsupportedPasswordProtectedKey\\('TFreePascalContext\\.LoadPrivateKey'\\);" \
  "FreePascal file private-key loader must fail-closed on non-empty password"
require_pcre "$freepascal_ctx" "procedure TFreePascalContext\\.LoadPrivateKey\\(AStream: TStream; const APassword: string\\);.*?if APassword <> '' then\\s+RejectUnsupportedPasswordProtectedKey\\('TFreePascalContext\\.LoadPrivateKey\\(AStream\\)'\\);" \
  "FreePascal stream private-key loader must fail-closed on non-empty password"
require_pcre "$freepascal_ctx" "procedure TFreePascalContext\\.LoadPrivateKeyPEM\\(const APEM: string; const APassword: string\\);.*?if APassword <> '' then\\s+RejectUnsupportedPasswordProtectedKey\\('TFreePascalContext\\.LoadPrivateKeyPEM'\\);" \
  "FreePascal PEM private-key loader must fail-closed on non-empty password"

require_fixed "$wolfssl_lib" "Result.SupportsPasswordProtectedKeys := False;" \
  "WolfSSL must not publish password-protected key capability before runtime support exists"
require_pcre "$wolfssl_ctx" "procedure TWolfSSLContext\\.LoadPrivateKey\\(const AFileName: string; const APassword: string\\);.*?if APassword <> '' then\\s+RejectUnsupportedPasswordProtectedKey\\('TWolfSSLContext\\.LoadPrivateKey'\\);" \
  "WolfSSL file private-key loader must fail-closed on non-empty password"
require_pcre "$wolfssl_ctx" "procedure TWolfSSLContext\\.LoadPrivateKey\\(AStream: TStream; const APassword: string\\);.*?if APassword <> '' then\\s+RejectUnsupportedPasswordProtectedKey\\('TWolfSSLContext\\.LoadPrivateKey\\(AStream\\)'\\);" \
  "WolfSSL stream private-key loader must fail-closed on non-empty password"
require_pcre "$wolfssl_ctx" "procedure TWolfSSLContext\\.LoadPrivateKeyPEM\\(const APEM: string; const APassword: string\\);.*?if APassword <> '' then\\s+RejectUnsupportedPasswordProtectedKey\\('TWolfSSLContext\\.LoadPrivateKeyPEM'\\);" \
  "WolfSSL PEM private-key loader must fail-closed on non-empty password"

require_fixed "$mbedtls_lib" "Result.SupportsPasswordProtectedKeys := True;" \
  "MbedTLS must keep published password-protected key support"
require_fixed "$winssl_lib" "Result.SupportsPasswordProtectedKeys := True;" \
  "WinSSL must keep published coarse-grained password-protected key support"

require_fixed "$backend_matrix" "| **Password-Protected Keys**  | ❌         | ✅      | ⚠️     | ✅      | ❌      |" \
  "backend capability matrix must publish current password-protected key truth"
require_fixed "$backend_matrix" '- `FreePascal` / `WolfSSL`: `SupportsPasswordProtectedKeys=False`；non-empty `APassword` 当前会 fail-closed' \
  "backend matrix must record false-backend fail-closed password truth"
require_fixed "$backend_matrix" '- `WinSSL`: 当前仅 password-protected PFX/P12 import path 已发布；PEM private-key password path 仍为 unsupported' \
  "backend matrix must record WinSSL partial password-protected key truth"

require_fixed "$api_reference" '在向 LoadPrivateKey(..., APassword) / LoadPrivateKeyPEM(..., APassword) 传入非空密码前，先检查 `ISSLLibrary.GetCapabilities.SupportsPasswordProtectedKeys`；对 `SupportsPasswordProtectedKeys=False` 的 backend，non-empty `APassword` 应抛出 unsupported，而不是 silent ignore。' \
  "API reference must record password-protected key fail-closed guidance"
require_fixed "$api_reference" "当前 WinSSL 仅发布 password-protected PFX/P12 import path；PEM private-key password path 仍为 unsupported。" \
  "API reference must record current WinSSL partial password-protected key truth"

require_fixed "$winssl_matrix" "| Password-protected private keys | ⚠️ 部分                   | 当前仅 password-protected PFX/P12 import path 已发布；PEM private-key password path 仍为 unsupported" \
  "WinSSL capability matrix must record current password-protected key partial-publication truth"

echo "[PASS] password-protected key capability truth remains aligned with source/docs/runtime contract"
