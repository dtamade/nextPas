#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/tests/winssl/test_winssl_integration_multi.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] winssl integration multi tls13 optional contract"

[[ -f "$FILE" ]] || fail "missing file: tests/winssl/test_winssl_integration_multi.pas"

if ! rg -F --quiet -- 'function IsOptionalTLS13OnlyFailure' "$FILE"; then
  fail "test_winssl_integration_multi.pas should classify TLS 1.3-only Schannel platform failures explicitly"
fi

if ! rg -F --quiet -- 'function HasAlgorithmMismatchNativeError' "$FILE"; then
  fail "test_winssl_integration_multi.pas should centralize Schannel algorithm-mismatch native-error detection"
fi

if ! rg -F --quiet -- '$80090331' "$FILE"; then
  fail "test_winssl_integration_multi.pas should guard the TLS 1.3-only path against the concrete 0x80090331 algorithm-mismatch native error"
fi

tls13_block="$(sed -n '/Test 2: TLS 1.3/,/Test 3: Auto-negotiation/p' "$FILE")"

if [[ "$tls13_block" != *"try"* ]] || [[ "$tls13_block" != *"except"* ]]; then
  fail "TLS 1.3-only negotiation block should catch platform-conditional exceptions instead of crashing the whole suite"
fi

if [[ "$tls13_block" != *"IsOptionalTLS13OnlyFailure(E)"* ]]; then
  fail "TLS 1.3-only negotiation block should route optional Schannel failures through IsOptionalTLS13OnlyFailure(E)"
fi

if [[ "$tls13_block" != *"TLS 1.3 协商（可能不支持）"* ]]; then
  fail "TLS 1.3-only negotiation block should keep the optional-platform pass path"
fi

echo "[PASS] winssl integration multi tls13 optional contract passed"
