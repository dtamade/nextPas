#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WINSSL_LIB="$ROOT_DIR/src/nextpas.core.tls.winssl.lib.pas"
WINSSL_DOC="$ROOT_DIR/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"

fail() {
  echo "[FAIL] $1"
  exit 1
}

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    echo "[PASS] $message"
  else
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$message"
  else
    echo "[PASS] $message"
  fi
}

echo "[TEST] WinSSL DTLS doc truth contract"

require_fixed "$WINSSL_LIB" \
  "Result.SupportsDTLS := False;  // Schannel 不支持 DTLS" \
  "WinSSL source must keep SupportsDTLS disabled"

require_fixed "$WINSSL_DOC" \
  '| DTLS 1.0 | ❌ 当前 capability 不发布 | ❌ 当前 capability 不发布 | ❌ 当前 capability 不发布 | 当前 WinSSL `SupportsDTLS=False`；Schannel backend 当前不发布 DTLS public/runtime path |' \
  "WinSSL dedicated matrix must describe DTLS 1.0 as unpublished capability"
require_fixed "$WINSSL_DOC" \
  '| DTLS 1.2 | ❌ 当前 capability 不发布 | ❌ 当前 capability 不发布 | ❌ 当前 capability 不发布 | 当前 WinSSL `SupportsDTLS=False`；Schannel backend 当前不发布 DTLS public/runtime path |' \
  "WinSSL dedicated matrix must describe DTLS 1.2 as unpublished capability"

require_absent "$WINSSL_DOC" \
  "| DTLS 1.0 | ✅ 支持     | ✅ 支持     | ⚠️ 部分   |                  |" \
  "WinSSL dedicated matrix must stop publishing DTLS 1.0 as supported"
require_absent "$WINSSL_DOC" \
  "| DTLS 1.2 | ✅ 支持     | ⚠️ 部分     | ❌ 不支持 |                  |" \
  "WinSSL dedicated matrix must stop publishing DTLS 1.2 as partially supported"

echo "[PASS] WinSSL DTLS doc truth contract passed"
