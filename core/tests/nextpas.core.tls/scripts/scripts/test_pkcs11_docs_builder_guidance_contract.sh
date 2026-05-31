#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

GUIDE_FILE="${PKCS11_GUIDE_DOC:-docs/guides/PKCS11_USER_GUIDE.md}"
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

assert_contains "$GUIDE_FILE" ".WithPKCS11PINMethod(pmEnvironment)" \
  "PKCS#11 guide lost the builder environment PIN example"
assert_contains "$GUIDE_FILE" ".WithPKCS11PINMethod(pmFile)" \
  "PKCS#11 guide lost the builder file PIN example"
facade_import_count="$( (rg -F -- '  fafafa.ssl,' "$GUIDE_FILE" || true) | wc -l | tr -d ' ' )"
if [[ "$facade_import_count" != "3" ]]; then
  echo "[FAIL] PKCS#11 guide must use the current public facade unit in all three active builder examples"
  echo "[INFO] expected 3 facade import lines, found: $facade_import_count"
  exit 1
fi
assert_contains "$GUIDE_FILE" "Builder 不支持 \`pmCallback\` 和 \`pmInteractive\`。" \
  "PKCS#11 guide no longer states that callback/interactive are not builder paths"
assert_contains "$GUIDE_FILE" "TPKCS11ConfigDefault" \
  "PKCS#11 guide lost the lower-level callback configuration example"
assert_contains "$GUIDE_FILE" "TPKCS11BackendFactory.CreateBackend" \
  "PKCS#11 guide no longer points callback guidance at the backend factory"
assert_contains "$GUIDE_FILE" "Config.PINCallback := @Provider.RequestPIN;" \
  "PKCS#11 guide no longer demonstrates the object-bound callback shape"

assert_not_contains "$GUIDE_FILE" ".WithPKCS11Key(" \
  "PKCS#11 guide still references removed WithPKCS11Key API"
assert_not_contains "$GUIDE_FILE" ".ForServer" \
  "PKCS#11 guide still references removed ForServer builder API"
assert_not_contains "$GUIDE_FILE" ".Build;" \
  "PKCS#11 guide still references removed Build method for the builder example"
assert_not_contains "$GUIDE_FILE" "function MyPINCallback(" \
  "PKCS#11 guide regressed to a free-function callback example"
assert_not_contains "$GUIDE_FILE" "  nextpas.core.tls.base," \
  "PKCS#11 guide still teaches nextpas.core.tls.base in active builder examples"

assert_contains "$ARCH_FILE" "**Builder Runtime Contract**:" \
  "PKCS#11 architecture doc lost the builder runtime contract section"
assert_contains "$ARCH_FILE" "\`pmEnvironment\`" \
  "PKCS#11 architecture doc lost pmEnvironment builder support guidance"
assert_contains "$ARCH_FILE" "\`pmFile\`" \
  "PKCS#11 architecture doc lost pmFile builder support guidance"
assert_contains "$ARCH_FILE" "function LoadCertificate(const AConfig: TPKCS11Config): PX509;" \
  "PKCS#11 architecture doc lost the current IPKCS11Backend certificate method"
assert_contains "$ARCH_FILE" "function GetName: string;" \
  "PKCS#11 architecture doc lost the current backend name method"
assert_contains "$ARCH_FILE" "function GetVersion: string;" \
  "PKCS#11 architecture doc lost the current backend version method"
assert_contains "$ARCH_FILE" "TProviderBackend = class(TBasePKCS11Backend)" \
  "PKCS#11 architecture doc lost the current provider backend class name"
assert_contains "$ARCH_FILE" "TEngineBackend = class(TBasePKCS11Backend)" \
  "PKCS#11 architecture doc lost the current engine backend class name"
assert_contains "$ARCH_FILE" "\`pmCallback\` and \`pmInteractive\` remain lower-level" \
  "PKCS#11 architecture doc lost the lower-level callback/interactive boundary"

assert_not_contains "$ARCH_FILE" "GetBackendType" \
  "PKCS#11 architecture doc regressed to the removed GetBackendType backend API"
assert_not_contains "$ARCH_FILE" "GetLastError" \
  "PKCS#11 architecture doc regressed to the removed GetLastError backend API"
assert_not_contains "$ARCH_FILE" "TPKCS11ProviderBackend" \
  "PKCS#11 architecture doc regressed to the old provider backend class name"
assert_not_contains "$ARCH_FILE" "TPKCS11EngineBackend" \
  "PKCS#11 architecture doc regressed to the old engine backend class name"

echo "[PASS] PKCS#11 docs keep the current builder/runtime guidance contract"
