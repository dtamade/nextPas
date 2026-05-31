#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/tests/unit/test_winssl_comprehensive.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] winssl comprehensive factory registration contract"

[[ -f "$FILE" ]] || fail "missing file: tests/unit/test_winssl_comprehensive.pas"

if ! rg -F --quiet -- 'procedure EnsureWinSSLBackendRegistered;' "$FILE"; then
  fail "test_winssl_comprehensive.pas should define an explicit WinSSL backend registration guard"
fi

if ! rg -F --quiet -- 'RegisterWinSSLBackend;' "$FILE"; then
  fail "test_winssl_comprehensive.pas should register the WinSSL backend before factory-based tests run"
fi

ensure_count="$(rg -F --count -- 'EnsureWinSSLBackendRegistered;' "$FILE")"
if [[ "$ensure_count" -lt 2 ]]; then
  fail "test_winssl_comprehensive.pas should call the backend registration guard from main"
fi

if ! rg -F --quiet -- 'TSSLFactory.GetLibraryInstance(sslWinSSL)' "$FILE"; then
  fail "test_winssl_comprehensive.pas no longer exercises the WinSSL factory path"
fi

echo "[PASS] winssl comprehensive factory registration contract passed"
