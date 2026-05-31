#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_ref="docs/reference/API_REFERENCE.md"

check_file() {
  local file="$1"
  local class_name="$2"

  if ! rg -n --quiet "if \\(AType = sslCtxServer\\) and \\(Trim\\(LConfig\\.ServerName\\) <> ''\\) then" "$file"; then
    echo "[FAIL] $file no longer rejects server-side direct-library ServerName"
    exit 1
  fi

  if ! rg -n --quiet "ServerName is client-scoped\\. Server-side connections ignore context-level ServerName;" "$file"; then
    echo "[FAIL] $file no longer explains server-side direct-library ServerName rejection"
    exit 1
  fi

  if ! rg -n --quiet "${class_name}\\.CreateContext received TSSLConfig\\.ServerName as deprecated context-level" "$file"; then
    echo "[FAIL] $file no longer warns about deprecated direct-library context-level ServerName"
    exit 1
  fi

  if ! rg -n --quiet "CreateContext ignores it for new contexts; prefer per-connection SNI via" "$file"; then
    echo "[FAIL] $file no longer explains the warning+ignore direct-library ServerName rule"
    exit 1
  fi
}

check_file "src/nextpas.core.tls.openssl.backed.pas" "TOpenSSLLibrary"
check_file "src/nextpas.core.tls.freepascal.lib.pas" "TFreePascalSSLLibrary"
check_file "src/nextpas.core.tls.winssl.lib.pas" "TWinSSLLibrary"
check_file "src/nextpas.core.tls.mbedtls.lib.pas" "TMbedTLSLibrary"
check_file "src/nextpas.core.tls.wolfssl.lib.pas" "TWolfSSLLibrary"

if ! rg -F -n --quiet '`ISSLLibrary.SetDefaultConfig(...)` + `ISSLLibrary.CreateContext(AType)` 这条 direct-library path 现在也已对齐：client default-config 会 warning + ignore，server default-config 会 reject。' "$api_ref"; then
  echo "[FAIL] API reference no longer records the aligned direct-library ServerName warning/reject truth"
  exit 1
fi

echo "[PASS] direct-library ServerName compatibility remains aligned across backend library paths"
