#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_ref="docs/reference/API_REFERENCE.md"

check_file() {
  local file="$1"
  local class_name="$2"

  if ! rg -n --quiet 'ValidateContextReplayStoreConfigScope\(' "$file"; then
    echo "[FAIL] $file does not validate direct-library replay-store client/server scope"
    exit 1
  fi

  if ! rg -F -n --quiet "'${class_name}.CreateContext'" "$file"; then
    echo "[FAIL] $file no longer tags the replay-store validation/apply callsite with ${class_name}.CreateContext"
    exit 1
  fi

  if ! rg -n --quiet 'ApplyEarlyDataContextConfig\(Result, LConfig\);' "$file"; then
    echo "[FAIL] $file does not apply early-data defaults on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'ApplyEarlyDataReplayStoreConfig\(Result, LConfig,' "$file"; then
    echo "[FAIL] $file does not apply direct-library replay-store defaults"
    exit 1
  fi
}

check_file "src/nextpas.core.tls.openssl.backed.pas" "TOpenSSLLibrary"
check_file "src/nextpas.core.tls.freepascal.lib.pas" "TFreePascalSSLLibrary"
check_file "src/nextpas.core.tls.winssl.lib.pas" "TWinSSLLibrary"
check_file "src/nextpas.core.tls.mbedtls.lib.pas" "TMbedTLSLibrary"
check_file "src/nextpas.core.tls.wolfssl.lib.pas" "TWolfSSLLibrary"

if ! rg -F -n --quiet '`ClientEarlyDataEnabled`' "$api_ref"; then
  echo "[FAIL] API reference no longer records direct-library early-data coverage"
  exit 1
fi

if ! rg -F -n --quiet '`ServerEarlyDataReplayStoreFile`' "$api_ref"; then
  echo "[FAIL] API reference no longer records direct-library replay-store coverage"
  exit 1
fi

if ! rg -F -n --quiet 'replay-store 仍保持 server-only 约束；若 backend 不实现 installer seam，则 direct-library server path 会 fail-fast。' "$api_ref"; then
  echo "[FAIL] API reference no longer records direct-library replay-store fail-fast truth"
  exit 1
fi

echo "[PASS] direct-library early-data and replay-store parity remains aligned across backend library paths"
