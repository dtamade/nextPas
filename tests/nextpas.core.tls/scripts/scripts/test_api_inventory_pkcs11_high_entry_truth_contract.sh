#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

INVENTORY_FILE="docs/reference/API_INVENTORY.md"
GUIDE_FILE="docs/guides/PKCS11_USER_GUIDE.md"
ARCH_FILE="docs/reference/PKCS11_ARCHITECTURE.md"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] top of $file:"
    sed -n '1,240p' "$file" || true
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if rg -F --quiet "$pattern" "$file"; then
    echo "[FAIL] $message"
    rg -n -F "$pattern" "$file" || true
    exit 1
  fi
}

assert_contains "$INVENTORY_FILE" "这是当前 public surface 的高层索引，不再维护历史 phase snapshot、测试统计或性能数字。" \
  "API inventory must declare itself as a current high-level index rather than a stale phase snapshot"
assert_contains "$INVENTORY_FILE" "TFreePascalContext" \
  "API inventory lost the FreePascal context implementation"
assert_contains "$INVENTORY_FILE" "TMbedTLSContext" \
  "API inventory lost the MbedTLS context implementation"
assert_contains "$INVENTORY_FILE" "TWolfSSLContext" \
  "API inventory lost the WolfSSL context implementation"
assert_contains "$INVENTORY_FILE" "TFreePascalConnection" \
  "API inventory lost the FreePascal connection implementation"
assert_contains "$INVENTORY_FILE" "TMbedTLSConnection" \
  "API inventory lost the MbedTLS connection implementation"
assert_contains "$INVENTORY_FILE" "TWolfSSLConnection" \
  "API inventory lost the WolfSSL connection implementation"
assert_contains "$INVENTORY_FILE" '当前 `GetOCSPStaplingEnabled` / `GetOCSPResponse` / `IsOCSPResponseVerified` / `GetOCSPResponseStatus` 兼容入口已经 shipped' \
  "API inventory must state that the legacy OCSP compatibility methods are shipped"
assert_contains "$INVENTORY_FILE" '当前 published PKCS#11 context path 只在 `OpenSSL` backend 暴露。' \
  "API inventory must state that the current published PKCS#11 context path is OpenSSL-only"
assert_contains "$INVENTORY_FILE" '`TPKCS11BackendFactory.IsBackendAvailable(btAuto)`' \
  "API inventory must mention the runtime-aware PKCS#11 readiness source"
assert_contains "$INVENTORY_FILE" '`WinSSL` / `FreePascal` / `MbedTLS` / `WolfSSL` 当前 `SupportsPKCS11=False`。' \
  "API inventory must state that non-OpenSSL backends do not currently publish PKCS#11 capability"
assert_not_contains "$INVENTORY_FILE" "**缺失方法** (待实现):" \
  "API inventory still claims shipped OCSP compatibility methods are missing"
assert_not_contains "$INVENTORY_FILE" "PKCS#11: 基础框架已完成,完整实现待完成" \
  "API inventory still claims PKCS#11 is only a partial future implementation"
assert_not_contains "$INVENTORY_FILE" "实现 OCSP Stapling 功能" \
  "API inventory still carries the stale next-step item to implement OCSP stapling"
assert_not_contains "$INVENTORY_FILE" "完成 PKCS#11 集成" \
  "API inventory still carries the stale next-step item to complete PKCS#11 integration"

assert_contains "$GUIDE_FILE" '当前 published PKCS#11 private-key path 只在 `OpenSSL` backend 暴露。' \
  "PKCS#11 user guide must declare the OpenSSL-only published path"
assert_contains "$GUIDE_FILE" '其它 backend 当前都不发布 `SupportsPKCS11` capability。' \
  "PKCS#11 user guide must state that other backends currently do not publish PKCS#11 capability"
assert_contains "$GUIDE_FILE" '`TPKCS11BackendFactory.IsBackendAvailable(btAuto)`' \
  "PKCS#11 user guide must mention the runtime-ready PKCS#11 capability source"
assert_contains "$GUIDE_FILE" '如果当前 OpenSSL runtime 既没有可用 Provider path，也没有可用 ENGINE path，`SupportsPKCS11` 会降为 `False`' \
  "PKCS#11 user guide must document the Provider/ENGINE readiness gate"

assert_contains "$ARCH_FILE" "The current published PKCS#11 context path is the OpenSSL backend integration." \
  "PKCS#11 architecture doc must declare the OpenSSL-only published path"
assert_contains "$ARCH_FILE" "procedure LoadPrivateKeyFromPKCS11(const AURI: string; const APIN: string);" \
  "PKCS#11 architecture doc must keep the current OpenSSL context PKCS#11 signature"
assert_contains "$ARCH_FILE" '`SupportsPKCS11` follows `TPKCS11BackendFactory.IsBackendAvailable(btAuto)`' \
  "PKCS#11 architecture doc must mention runtime-aware PKCS#11 capability truth"
assert_contains "$ARCH_FILE" 'Other SSL backends currently publish `SupportsPKCS11=False`.' \
  "PKCS#11 architecture doc must state the non-OpenSSL backend boundary"
assert_not_contains "$ARCH_FILE" "APINMethod: TPKCS11PINMethod = pmNone" \
  "PKCS#11 architecture doc regressed to an old LoadPrivateKeyFromPKCS11 signature"

echo "[PASS] API inventory and PKCS#11 high-entry docs match the current source truth"
