#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

guide="docs/guides/STORE_USAGE_GUIDE.md"

echo "[TEST] STORE_USAGE_GUIDE current public import truth"

require_fixed "$guide" "  fafafa.ssl," \
  "STORE_USAGE_GUIDE must use the current public facade import in active examples"
require_fixed "$guide" "  nextpas.core.tls.winssl.certstore;" \
  "STORE_USAGE_GUIDE must keep the WinSSL certstore helper import for Windows-specific store access"
require_fixed "$guide" "LStore := OpenSystemStore(SSL_STORE_MY);" \
  "STORE_USAGE_GUIDE must keep the shipped WinSSL system-store helper path"
require_fixed "$guide" "LStore := TSSLFactory.CreateCertificateStore(sslAutoDetect);" \
  "STORE_USAGE_GUIDE must keep the generic factory-based certificate-store entrypoint"
require_absent "$guide" "nextpas.core.tls.base," \
  "STORE_USAGE_GUIDE must stop teaching split base-unit imports in active examples"
require_absent "$guide" "nextpas.core.tls.factory," \
  "STORE_USAGE_GUIDE must stop teaching split factory-unit imports in active examples"

echo "[PASS] STORE_USAGE_GUIDE current public import truth is satisfied."
