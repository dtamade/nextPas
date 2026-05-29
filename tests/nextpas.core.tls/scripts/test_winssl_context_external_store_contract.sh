#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

FILE="src/nextpas.core.tls.winssl.context.pas"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] relevant context from $file:"
    sed -n '1230,1260p' "$file" || true
    exit 1
  fi
}

assert_contains "$FILE" \
  "if (Result = nil) and (FExternalCertStore <> nil) then" \
  "GetCAStoreHandle should fall back to the externally injected certificate store"
assert_contains "$FILE" \
  "TryGetNativeHandle(FExternalCertStore, LStoreHandle)" \
  "GetCAStoreHandle should resolve the native handle from FExternalCertStore"
assert_contains "$FILE" \
  "Result := HCERTSTORE(LStoreHandle);" \
  "GetCAStoreHandle should expose the external store handle to the validation path"

echo "[PASS] WinSSL context exposes injected external certificate stores to chain validation"
