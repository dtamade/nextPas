#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$PROJECT_ROOT"

shared_helper="core/src/nextpas.core.tls.context.config.pas"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"
  if ! grep -Fq "$needle" "$file"; then
    echo "[FAIL] $message"
    echo "  missing: $needle"
    echo "  file: $file"
    exit 1
  fi
}



require_fixed 'procedure ValidateDirectLibraryConnectionScope(const AConfig: TSSLConfig;' \
  "$shared_helper" \
  "shared direct-library connection-scope validator is missing"
require_fixed 'HandshakeTimeout is connection-scoped. Use TSSLConnector.WithTimeout, ' \
  "$shared_helper" \
  "shared direct-library validator no longer mentions HandshakeTimeout replacement path"
require_fixed 'ISSLConnectionControl.SetTimeout instead of ' \
  "$shared_helper" \
  "shared direct-library validator no longer points to the current timeout runtime owner"
require_fixed 'BufferSize is not a context-scoped direct-library option. Configure buffering in the surrounding ' \
  "$shared_helper" \
  "shared direct-library validator no longer mentions BufferSize replacement path"

check_backend() {
  local file="$1"
  if ! rg -n --quiet 'ValidateDirectLibraryConnectionScope\(' "$file"; then
    echo "[FAIL] $file does not call the shared direct-library connection-scope validator"
    exit 1
  fi
}

check_backend "core/src/nextpas.core.tls.openssl.backed.pas"
check_backend "core/src/nextpas.core.tls.freepascal.lib.pas"
check_backend "core/src/nextpas.core.tls.winssl.lib.pas"
check_backend "core/src/nextpas.core.tls.mbedtls.lib.pas"
check_backend "core/src/nextpas.core.tls.wolfssl.lib.pas"

echo "[PASS] direct-library connection-scope clarification remains aligned across backend library paths"
