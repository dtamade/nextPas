#!/usr/bin/env bash
set -euo pipefail

DOC="docs/reference/ARCHITECTURE.md"

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

require_contains 'nextpas.core.tls.base'
require_contains 'TSSLContextBuilder'
require_contains 'TSSLConnector'
require_contains 'TSSLFactory.GetLibraryInstance'
require_contains 'class function CreateContext(AContextType: TSSLContextType;'
require_contains 'class function GetAvailableLibraries: TSSLLibraryTypes;'

require_absent 'nextpas.core.tls.types'
require_absent 'nextpas.core.tls.intf'
require_absent 'class function CreateContext(ALibType: TSSLLibraryType;'
require_absent 'TSSLLibraryTypeSet'

echo "[PASS] reference ARCHITECTURE current factory surface truth contract passed"
