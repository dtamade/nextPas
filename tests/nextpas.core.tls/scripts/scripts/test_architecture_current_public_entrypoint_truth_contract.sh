#!/usr/bin/env bash
set -euo pipefail

DOC="docs/ARCHITECTURE.md"

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
require_contains 'TSSLFactory.GetLibraryInstance('
require_contains 'TSSLFactory.CreateContext('
require_contains 'WinSSL=200'
require_contains 'MbedTLS=175'
require_contains 'WolfSSL=150'
require_contains 'OpenSSL=100'
require_contains 'FreePascal=50'
require_contains 'nextpas.core.tls.openssl.backed.pas'
require_contains 'nextpas.core.tls.freepascal.'
require_contains 'nextpas.core.tls.native_handle'
require_contains '当前 public Pascal source 只声明了 `ISSLClientConnection`'

require_absent 'Ctx := Factory.CreateContext('
require_absent 'class function CreateLibrary('
require_absent 'OpenSSL (优先级 10)'
require_absent 'WinSSL  (优先级 10)'
require_absent '纯 FreePascal TLS 后端（Phase 1: 密码学原语）'
require_absent 'nextpas.core.tls.openssl.lib.pas'

echo "[PASS] ARCHITECTURE current public entrypoint truth contract passed"
