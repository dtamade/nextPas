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

example_cert_pinning="examples/example_cert_pinning.pas"
example_error_handling="examples/example_error_handling.pas"
example_result_type="examples/example_result_type.pas"
example_streaming_operations="examples/example_streaming_operations.pas"
test_ssl_context="examples/test_ssl_context.lpr"
generate_certificate="examples/02_generate_certificate.pas"
winssl_fips="examples/09_winssl_fips.pas"

echo "[TEST] specialized / utility examples public import truth contract"

require_fixed "$example_cert_pinning" "  fafafa.ssl," \
  "example_cert_pinning must use the public facade unit"
require_fixed "$example_cert_pinning" "  nextpas.core.tls.cert.pinning;" \
  "example_cert_pinning must keep the pinning owner unit"

require_fixed "$example_error_handling" "  fafafa.ssl," \
  "example_error_handling must use the public facade unit"
require_fixed "$example_error_handling" "  nextpas.core.tls.exceptions;" \
  "example_error_handling must keep the exceptions owner unit"

require_fixed "$example_result_type" "  fafafa.ssl," \
  "example_result_type must use the public facade unit"
require_fixed "$example_result_type" "  nextpas.core.tls.crypto.utils," \
  "example_result_type must keep crypto owner unit"

require_fixed "$example_streaming_operations" "  fafafa.ssl," \
  "example_streaming_operations must use the public facade unit for TBytesView"
require_fixed "$example_streaming_operations" "  nextpas.core.tls.crypto.utils," \
  "example_streaming_operations must keep crypto owner unit"
require_fixed "$example_streaming_operations" "  nextpas.core.tls.encoding;" \
  "example_streaming_operations must keep encoding owner unit"

require_fixed "$test_ssl_context" "  fafafa.ssl," \
  "test_ssl_context must use the public facade unit"
require_fixed "$test_ssl_context" "  nextpas.core.tls.openssl.backed," \
  "test_ssl_context must keep OpenSSL backend owner unit"

require_fixed "$generate_certificate" "  fafafa.ssl," \
  "02_generate_certificate must use the public facade unit"
require_fixed "$generate_certificate" "  nextpas.core.tls.openssl.backed," \
  "02_generate_certificate must keep OpenSSL backend owner unit"

require_fixed "$winssl_fips" "  WriteLn('    fafafa.ssl;');" \
  "09_winssl_fips must print the public facade import guidance"
require_absent "$winssl_fips" "nextpas.core.tls.factory," \
  "09_winssl_fips must stop printing factory split-import guidance"
require_absent "$winssl_fips" "nextpas.core.tls.base;" \
  "09_winssl_fips must stop printing base split-import guidance"

for file in \
  "$example_cert_pinning" \
  "$example_error_handling" \
  "$example_result_type" \
  "$example_streaming_operations" \
  "$test_ssl_context" \
  "$generate_certificate"; do
  require_absent "$file" "nextpas.core.tls.base" \
    "$file must stop teaching direct base-unit imports in specialized / utility examples"
  require_absent "$file" "nextpas.core.tls.factory" \
    "$file must stop teaching direct factory-unit imports in specialized / utility examples"
done

echo "[PASS] specialized / utility examples public import truth contract passed"
