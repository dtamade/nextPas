#!/usr/bin/env bash
set -euo pipefail

DOC="docs/MIGRATION_GUIDE_V1.1.md"

require_contains() {
  local pattern="$1"
  if ! rg -F -q "$pattern" "$DOC"; then
    echo "[FAIL] missing pattern: $pattern" >&2
    exit 1
  fi
}

require_absent() {
  local pattern="$1"
  if rg -F -q "$pattern" "$DOC"; then
    echo "[FAIL] unexpected pattern present: $pattern" >&2
    exit 1
  fi
}

require_contains 'TSSLContextBuilder'
require_contains 'TSSLConnector'
require_contains 'TSSLFactory.GetLibraryInstance(sslOpenSSL)'
require_contains 'nextpas.core.tls.native_handle'
require_contains '当前仓库已经包含 `sslFreePascal` backend'
require_contains 'TryGetNativeHandleAs<PSSL_CTX>'

require_absent 'TSSLFactory.CreateLibrary('
require_absent 'Factory.CreateContext('
require_absent 'TSSLFactory.GetLibrary('
require_absent 'Pointer(SSL_CTX)'
require_absent 'AContextMsg'

echo "[PASS] MIGRATION_GUIDE current public entrypoint truth contract passed"
