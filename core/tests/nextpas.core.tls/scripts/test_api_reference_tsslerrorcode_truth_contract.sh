#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

doc_file="docs/reference/API_REFERENCE.md"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local pattern="$1"
  local message="$2"
  if ! rg -F -n --quiet -- "$pattern" "$doc_file"; then
    fail "$message"
  fi
}

require_absent() {
  local pattern="$1"
  local message="$2"
  if rg -F -n --quiet -- "$pattern" "$doc_file"; then
    fail "$message"
  fi
}

echo "[TEST] API reference TSSLErrorCode truth contract"

require_fixed "sslErrNone,              // 无错误" \
  "API reference must keep the current no-error enum truth"
require_fixed "sslErrMemory,            // 内存分配错误" \
  "API reference must keep the current memory-error enum truth"
require_fixed "sslErrInvalidParam,      // 无效参数" \
  "API reference must keep the current invalid-parameter enum truth"
require_fixed "sslErrHandshake,         // 握手错误" \
  "API reference must keep the current handshake enum truth"
require_fixed "sslErrCertificate,       // 证书错误" \
  "API reference must keep the current certificate enum truth"
require_fixed "sslErrConnection,        // 连接错误" \
  "API reference must keep the current connection enum truth"
require_fixed "sslErrUnsupported,       // 不支持的功能" \
  "API reference must keep the current unsupported enum truth"
require_fixed "sslErrLoadFailed,        // 加载失败" \
  "API reference must keep the current load-failed enum truth"
require_fixed "sslErrOther              // 其他错误" \
  "API reference must keep the current fallback error enum truth"

require_absent "sslErrInvalidParameter" \
  "API reference must not regress to the removed sslErrInvalidParameter name"
require_absent "sslErrOutOfMemory" \
  "API reference must not regress to the removed sslErrOutOfMemory name"
require_absent "sslErrConnectionClosed" \
  "API reference must not regress to the removed sslErrConnectionClosed name"
require_absent "sslErrHandshakeFailed" \
  "API reference must not regress to the removed sslErrHandshakeFailed name"
require_absent "sslErrCertificateVerifyFailed" \
  "API reference must not regress to the removed sslErrCertificateVerifyFailed name"
require_absent "sslErrCipherNotSupported" \
  "API reference must not regress to the removed sslErrCipherNotSupported name"
require_absent "sslErrProtocolNotSupported" \
  "API reference must not regress to the removed sslErrProtocolNotSupported name"

echo "[PASS] API reference TSSLErrorCode truth anchors present"
