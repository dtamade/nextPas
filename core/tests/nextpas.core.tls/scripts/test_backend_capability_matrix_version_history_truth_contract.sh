#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
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

base_unit="core/src/nextpas.core.tls.base.pas"

echo "[TEST] backend capability matrix version-history truth contract"

require_fixed "$base_unit" "SSL_VERSION_STRING = '1.6.0';" \
  "Source version truth must remain v1.6.0"


echo "[PASS] backend capability matrix version-history truth contract passed"
