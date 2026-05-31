#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/src/nextpas.core.tls.winssl.connection.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] winssl connection safe statistics update contract"

[[ -f "$FILE" ]] || fail "missing file: src/nextpas.core.tls.winssl.connection.pas"

if ! rg -F --quiet -- 'procedure TryUpdateLibraryStatistics' "$FILE"; then
  fail "WinSSL connection should centralize library statistics updates behind a safety guard"
fi

helper_count="$(rg -F --count -- 'TryUpdateLibraryStatistics' "$FILE")"
if [[ "$helper_count" -lt 3 ]]; then
  fail "TryUpdateLibraryStatistics should be declared and used from both DoConnect and DoAccept"
fi

direct_handshake_count="$(rg -F --count -- 'UpdateHandshakeStatistics(' "$FILE")"
if [[ "$direct_handshake_count" -gt 1 ]]; then
  fail "UpdateHandshakeStatistics should not be called directly from multiple runtime paths"
fi

direct_session_count="$(rg -F --count -- 'UpdateSessionStatistics(' "$FILE")"
if [[ "$direct_session_count" -gt 1 ]]; then
  fail "UpdateSessionStatistics should not be called directly from multiple runtime paths"
fi

echo "[PASS] winssl connection safe statistics update contract passed"
