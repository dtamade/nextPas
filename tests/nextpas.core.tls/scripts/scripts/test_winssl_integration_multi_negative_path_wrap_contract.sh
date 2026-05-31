#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/tests/winssl/test_winssl_integration_multi.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] winssl integration multi negative-path wrap contract"

[[ -f "$FILE" ]] || fail "missing file: tests/winssl/test_winssl_integration_multi.pas"

if ! rg -F --quiet -- 'procedure TestExpectedHandshakeFailurePath' "$FILE"; then
  fail "test_winssl_integration_multi.pas should centralize negative-path handshake checks behind a helper"
fi

helper_count="$(rg -F --count -- 'TestExpectedHandshakeFailurePath(' "$FILE")"
if [[ "$helper_count" -lt 3 ]]; then
  fail "negative-path helper should be declared and used for HTTP-port plus SSL3 scenarios"
fi

ssl3_block="$(sed -n '/Test 3: Mismatched protocol/,/Test 4: Connection timeout/p' "$FILE")"
if [[ "$ssl3_block" == *'LConn := LContext.CreateConnection(LSocket);'* ]] && [[ "$ssl3_block" != *'TestExpectedHandshakeFailurePath('* ]]; then
  fail "SSL3 negative path should not create the WinSSL connection outside the helper/try guard"
fi

echo "[PASS] winssl integration multi negative-path wrap contract passed"
