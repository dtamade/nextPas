#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] excerpt from $file:"
    sed -n '1,240p' "$file" || true
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if rg -n -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    rg -n -F -- "$pattern" "$file" || true
    exit 1
  fi
}

assert_not_contains "docs/guides/COMMON_PITFALLS.md" \
  "WithVerifyHostname" \
  "COMMON_PITFALLS still teaches a nonexistent hostname-verification builder API"
assert_not_contains "docs/guides/security-best-practices.md" \
  "WithVerifyHostname" \
  "security-best-practices still teaches a nonexistent hostname-verification builder API"

assert_contains "docs/guides/COMMON_PITFALLS.md" \
  "TLS := TSSLConnector.FromContext(Ctx);" \
  "COMMON_PITFALLS lost the connector-based hostname verification guidance"
assert_contains "docs/guides/COMMON_PITFALLS.md" \
  "Stream := TLS.ConnectSocket(Socket, 'api.example.com');" \
  "COMMON_PITFALLS no longer shows connection-level hostname configuration"
assert_contains "docs/guides/security-best-practices.md" \
  "ClientConn := Conn as ISSLClientConnection;" \
  "security-best-practices should show explicit client-connection hostname setup"
assert_contains "docs/guides/security-best-practices.md" \
  "ClientConn.SetServerName('example.com');" \
  "security-best-practices should teach SetServerName on the connection"

assert_contains "docs/CA_CERTIFICATE_AUTO_LOADING.md" \
  "WithSystemRoots" \
  "CA auto-loading doc should point readers at the supported system-roots path"
assert_not_contains "docs/CA_CERTIFICATE_AUTO_LOADING.md" \
  "System CA certificates AUTOMATICALLY loaded!" \
  "CA auto-loading doc still promises automatic client-context CA loading"
assert_not_contains "docs/CA_CERTIFICATE_AUTO_LOADING.md" \
  "SSL_CTX_set_default_verify_paths(" \
  "CA auto-loading doc still treats SSL_CTX_set_default_verify_paths as active runtime guidance"

assert_not_contains "docs/PLATFORM_SUPPORT.md" \
  "Linux/macOS: OpenSSL" \
  "platform support doc still hardcodes Linux/macOS auto-detect to OpenSSL"
assert_contains "docs/PLATFORM_SUPPORT.md" \
  "highest-priority available backend" \
  "platform support doc should describe the factory as priority-based"
assert_contains "docs/PLATFORM_SUPPORT.md" \
  "WinSSL=200, MbedTLS=175, WolfSSL=150, OpenSSL=100" \
  "platform support doc should record the current backend priority order"

echo "[PASS] active TLS guidance docs stay aligned with the current runtime contract"
