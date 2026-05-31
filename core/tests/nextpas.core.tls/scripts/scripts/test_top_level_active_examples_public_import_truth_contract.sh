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

factory_usage="examples/example_factory_usage.pas"
cert_verify="examples/certificate_verification_example.pas"
winssl_downloader="examples/winssl_https_downloader.pas"
https_server="examples/05_https_server.pas"
digital_signature="examples/06_digital_signature.pas"
mutual_tls="examples/08_mutual_tls.pas"

echo "[TEST] top-level active examples public import truth contract"

for file in \
  "$factory_usage" \
  "$cert_verify" \
  "$winssl_downloader" \
  "$https_server" \
  "$digital_signature" \
  "$mutual_tls"; do
  require_fixed "$file" "fafafa.ssl" \
    "$file must use the public facade unit in top-level active examples"
  require_absent "$file" "nextpas.core.tls.base" \
    "$file must stop teaching direct base-unit imports in top-level active examples"
  require_absent "$file" "nextpas.core.tls.factory" \
    "$file must stop teaching direct factory-unit imports in top-level active examples"
done

require_fixed "$factory_usage" "LibraryTypeToString(" \
  "example_factory_usage must use the facade helper for library names"
require_absent "$factory_usage" "SSL_LIBRARY_NAMES[" \
  "example_factory_usage must stop reaching into the base-owner name table"

echo "[PASS] top-level active examples public import truth contract passed"
