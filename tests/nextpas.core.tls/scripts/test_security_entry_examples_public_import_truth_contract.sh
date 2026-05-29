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

simple_test="examples/simple_test.pas"
cert_pinning_simple="examples/example_cert_pinning_simple.pas"
security_demo="examples/security_enhancements_demo.pas"

echo "[TEST] security entry examples public import truth contract"

require_fixed "$simple_test" "  fafafa.ssl," \
  "simple_test must use the public facade unit alongside helper units"
require_fixed "$cert_pinning_simple" "nextpas.core.tls.cert.pinning" \
  "example_cert_pinning_simple must keep the specialized pinning unit"
require_fixed "$security_demo" "  fafafa.ssl," \
  "security_enhancements_demo must use the public facade unit"
require_fixed "$security_demo" "nextpas.core.tls.context.builder" \
  "security_enhancements_demo must keep the current builder unit"
require_fixed "$security_demo" "nextpas.core.tls.cert.pinning" \
  "security_enhancements_demo must keep the specialized pinning unit"
require_fixed "$security_demo" "nextpas.core.tls.cert.rotation" \
  "security_enhancements_demo must keep the specialized rotation unit"

for file in \
  "$simple_test" \
  "$cert_pinning_simple" \
  "$security_demo"; do
  require_absent "$file" "nextpas.core.tls.base" \
    "$file must stop teaching direct base-unit imports in security entry examples"
  require_absent "$file" "nextpas.core.tls.factory" \
    "$file must stop teaching direct factory-unit imports in security entry examples"
done

echo "[PASS] security entry examples public import truth contract passed"
