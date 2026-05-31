#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_FILE="$ROOT_DIR/src/nextpas.core.tls.base.pas"
WINSSL_LIB="$ROOT_DIR/src/nextpas.core.tls.winssl.lib.pas"
API_REF="$ROOT_DIR/docs/reference/API_REFERENCE.md"
MATRIX_DOC="$ROOT_DIR/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
GUIDE_DOC="$ROOT_DIR/docs/guides/WINSSL_USER_GUIDE.md"

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

require_fixed "$API_REF" \
  "    SessionCacheSupport: TSSLFeatureSupportLevel;" \
  "API reference capability record must list SessionCacheSupport explicitly"

require_fixed "$API_REF" \
  "- 当 \`SNISupport\` / \`ALPNSupport\` / \`OCSPStaplingSupport\` / \`CertTransparencySupport\` / \`SessionTicketsSupport\` / \`SessionCacheSupport\` 出现时，它们是当前 source/runtime truth；legacy \`SupportsSNI\` / \`SupportsALPN\` / \`SupportsOCSPStapling\` / \`SupportsCertificateTransparency\` / \`SupportsSessionTickets\` 仅作为兼容投影。" \
  "API reference read-priority note must include SessionCacheSupport"

require_fixed "$API_REF" \
  "- \`SessionCacheSupport\` 表示 context-scoped session cache/control surface 的 published support level；对 WinSSL 而言，它不等于当前已 runtime-proven 的 resumed handshake 结果。" \
  "API reference must explain the WinSSL SessionCacheSupport semantic boundary"

require_fixed "$MATRIX_DOC" \
  "| Session Cache  | ✅ 支持   | 系统管理；\`SessionCacheSupport=sslSupportStable\` 代表 context-level cache/control surface 已发布且已接线，不等于当前已 runtime-proven 的 resumed handshake |" \
  "WinSSL backend matrix must define stable SessionCacheSupport as cache/control truth only"

require_fixed "$GUIDE_DOC" \
  "- ⚠️ \`SessionCacheSupport=sslSupportStable\` 在 WinSSL 上当前表示 context-level session cache/control surface 已发布且已接线；是否真的命中 resumed handshake 仍要看 dedicated Windows runtime proof" \
  "WinSSL user guide must keep the SessionCacheSupport semantic boundary"

echo "[PASS] WinSSL session-cache semantic boundary contract passed"
