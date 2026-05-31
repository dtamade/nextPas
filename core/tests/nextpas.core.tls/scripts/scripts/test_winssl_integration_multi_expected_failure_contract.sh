#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/tests/winssl/test_winssl_integration_multi.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] winssl integration multi expected failure contract"

[[ -f "$FILE" ]] || fail "missing file: tests/winssl/test_winssl_integration_multi.pas"

if ! rg -F --quiet -- 'function IsExpectedHandshakeFailure' "$FILE"; then
  fail "test_winssl_integration_multi.pas should classify expected handshake/protocol failures explicitly"
fi

direct_expected_fail_count="$(rg -F --count -- 'IsExpectedHandshakeFailure(E)' "$FILE")"
helper_expected_fail_count="$(rg -F --count -- "TestExpectedHandshakeFailurePath('" "$FILE")"
if [[ "$direct_expected_fail_count" -lt 2 && "$helper_expected_fail_count" -lt 2 ]]; then
  fail "expected failure classification should cover both HTTP-port and SSL3 negative-path assertions, either directly or through the centralized helper"
fi

if rg -F --quiet -- 'Length(LResponse) >= 1024' "$FILE"; then
  fail "medium-size transfer assertion should not depend on a brittle 1024-byte threshold"
fi

if ! rg -F --quiet -- 'Length(LResponse) >= 512' "$FILE"; then
  fail "medium-size transfer assertion should use the current stable threshold"
fi

echo "[PASS] winssl integration multi expected failure contract passed"
