#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/tests/integration/test_backend_comparison.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] backend comparison factory registration contract"

[[ -f "$FILE" ]] || fail "missing file: tests/integration/test_backend_comparison.pas"

if ! rg -F --quiet -- 'nextpas.core.tls.winssl.lib' "$FILE"; then
  fail "test_backend_comparison.pas should import nextpas.core.tls.winssl.lib so Windows factory tests can register WinSSL"
fi

if ! rg -F --quiet -- 'procedure EnsureWinSSLBackendRegistered;' "$FILE"; then
  fail "test_backend_comparison.pas should define an explicit WinSSL backend registration guard"
fi

if ! rg -F --quiet -- 'RegisterWinSSLBackend;' "$FILE"; then
  fail "test_backend_comparison.pas should register the WinSSL backend before factory-based comparison tests run"
fi

ensure_count="$(rg -F --count -- 'EnsureWinSSLBackendRegistered;' "$FILE")"
if [[ "$ensure_count" -lt 2 ]]; then
  fail "test_backend_comparison.pas should invoke the WinSSL backend registration guard from the Windows entry path"
fi

if ! rg -F --quiet -- 'TSSLFactory.GetLibraryInstance(sslWinSSL)' "$FILE"; then
  fail "test_backend_comparison.pas no longer exercises the WinSSL factory path"
fi

echo "[PASS] backend comparison factory registration contract passed"
