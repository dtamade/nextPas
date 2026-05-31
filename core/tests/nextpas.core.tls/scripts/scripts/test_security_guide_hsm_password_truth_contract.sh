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

guide="docs/guides/SECURITY_GUIDE.md"

echo "[TEST] Security guide HSM/password-key truth contract"

require_fixed "$guide" '在向 `LoadPrivateKey(..., APassword)` / `LoadPrivateKeyPEM(..., APassword)` 传入非空密码前，先检查 `ISSLLibrary.GetCapabilities.SupportsPasswordProtectedKeys`。' \
  "Security guide must mention the current password-protected-key capability gate"
require_fixed "$guide" '当前 `WinSSL` 只有 password-protected PFX/P12 import path；PEM private-key password path 仍为 unsupported。' \
  "Security guide must mention the current WinSSL password-protected-key boundary"
require_fixed "$guide" '当前 published HSM / PKCS#11 private-key path 只在 `OpenSSL` backend 暴露。' \
  "Security guide must state the OpenSSL-only PKCS#11 published path"
require_fixed "$guide" "if not LLib.GetCapabilities.SupportsPKCS11 then" \
  "Security guide HSM example must gate on runtime-aware PKCS#11 capability"
require_fixed "$guide" "LContext.LoadPrivateKey('pkcs11:token=ProdToken;object=ServerKey;type=private?module-path=/usr/lib/softhsm/libsofthsm2.so', 'pin');" \
  "Security guide HSM example must use the current PKCS#11 URI loading path"
require_fixed "$guide" "[PKCS#11 用户指南](PKCS11_USER_GUIDE.md)" \
  "Security guide must link readers to the dedicated PKCS#11 guide"

require_absent "$guide" "LoadPKCS11Engine(" \
  "Security guide must stop using nonexistent PKCS#11 engine helper APIs"
require_absent "$guide" "LoadKeyFromHSM(" \
  "Security guide must stop using nonexistent HSM key-loading helpers"
require_absent "$guide" ".SetPrivateKey(" \
  "Security guide must stop using nonexistent SetPrivateKey context APIs"

echo "[PASS] Security guide HSM/password-key truth contract passed"
