#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BASE_FILE="$ROOT_DIR/core/src/nextpas.core.tls.base.pas"
WINSSL_LIB="$ROOT_DIR/core/src/nextpas.core.tls.winssl.lib.pas"

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

echo "[TEST] WinSSL session-cache semantic boundary contract"

require_fixed "$BASE_FILE" \
  "SessionCacheSupport: TSSLFeatureSupportLevel;     // 会话缓存支持级别（cache/control surface，不保证已观测到 resumed handshake）" \
  "Base capability record must define SessionCacheSupport as cache/control support rather than resumed-handshake proof"

require_fixed "$WINSSL_LIB" \
  "// \`SessionCacheSupport\` 在 WinSSL 上当前表示 context-level cache/control" \
  "WinSSL capability source must explain what stable SessionCacheSupport actually means"

require_fixed "$WINSSL_LIB" \
  "// surface 已发布且已接线，不等于已 runtime-proven 的 resumed handshake。" \
  "WinSSL capability source must keep the resumed-handshake caveat next to SessionCacheSupport"






echo "[PASS] WinSSL session-cache semantic boundary contract passed"
