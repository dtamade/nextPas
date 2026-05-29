#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

require_fixed() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

logging_runtime="tests/test_clibrary_library_default_logging_scope_clarification.pas"
connection_runtime="tests/test_clibrary_library_default_config_connection_scope_clarification.pas"

for runtime_file in "$logging_runtime" "$connection_runtime"; do
  require_fixed "sslOpenSSL," "$runtime_file" \
    "$runtime_file no longer names the OpenSSL backend enum"
  require_fixed "sslMbedTLS," "$runtime_file" \
    "$runtime_file no longer names the MbedTLS backend enum"
  require_fixed "sslWolfSSL," "$runtime_file" \
    "$runtime_file no longer names the WolfSSL backend enum"
  require_fixed "@CreateOpenSSLLibrary" "$runtime_file" \
    "$runtime_file no longer exercises the OpenSSL direct-library path"
  require_fixed "@CreateMbedTLSLibrary" "$runtime_file" \
    "$runtime_file no longer exercises the MbedTLS direct-library path"
  require_fixed "@CreateWolfSSLLibrary" "$runtime_file" \
    "$runtime_file no longer exercises the WolfSSL direct-library path"
  require_fixed "backend not available on this platform" "$runtime_file" \
    "$runtime_file no longer preserves explicit optional-backend skip semantics"
done

require_fixed "SetDefaultConfig keeps LogCallback detached from the default-config write surface" "$logging_runtime" \
  "C-library logging runtime proof no longer asserts SetDefaultConfig callback detachment"
require_fixed "SetLogCallback visibleizes callback in GetDefaultConfig" "$logging_runtime" \
  "C-library logging runtime proof no longer asserts SetLogCallback ownership"
require_fixed "Log dispatches messages at configured LogLevel" "$logging_runtime" \
  "C-library logging runtime proof no longer asserts filtered log dispatch"

require_fixed "ISSLConnectionControl.SetTimeout" "$connection_runtime" \
  "C-library connection-scope runtime proof no longer asserts HandshakeTimeout replacement guidance"
require_fixed "transport/IO" "$connection_runtime" \
  "C-library connection-scope runtime proof no longer asserts BufferSize replacement guidance"
require_fixed "still succeeds when default config keeps request-safe connection scope fields" "$connection_runtime" \
  "C-library connection-scope runtime proof no longer asserts the safe-default build path"

echo "[PASS] C-library direct-library runtime parity proof stays aligned"
