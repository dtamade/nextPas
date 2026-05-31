#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_FILE="$ROOT_DIR/src/nextpas.core.tls.wolfssl.api.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

if [[ ! -f "$API_FILE" ]]; then
  fail "missing source file: src/nextpas.core.tls.wolfssl.api.pas"
fi

if ! rg -n --fixed-strings -- "LoadLibrary(WOLFSSL_LIB_NAME)" "$API_FILE" >/dev/null; then
  fail "wolfssl api loader must still attempt the canonical library name first"
fi

if ! rg -n --pcre2 'libwolfssl\.so\*|/usr/lib/x86_64-linux-gnu|/lib/x86_64-linux-gnu|/usr/lib64|/lib64|/usr/local/lib' "$API_FILE" >/dev/null; then
  fail "wolfssl api loader must include Linux fallback search paths/versioned soname scanning after the canonical load attempt fails"
fi

echo "[PASS] wolfssl loader fallback contract passed"
