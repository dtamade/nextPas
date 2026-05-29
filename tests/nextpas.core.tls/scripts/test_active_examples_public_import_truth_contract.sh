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

https_rest_client="examples/04_https_rest_client.pas"
certificate_chain="examples/07_certificate_chain.pas"
demo_fluent_api="examples/demo_fluent_api.pas"
winssl_health_checker="examples/winssl_health_checker.pas"
winssl_rest_client="examples/winssl_rest_client.pas"
tcp_helper="examples/fafafa.examples.tcp.pas"
real_world_test="examples/validation/real_world_test.pas"

echo "[TEST] active examples public import truth contract"

require_fixed "$https_rest_client" "  fafafa.ssl;" \
  "04_https_rest_client must use the public facade unit"
require_fixed "$certificate_chain" "  fafafa.ssl;" \
  "07_certificate_chain must use the public facade unit"
require_fixed "$demo_fluent_api" "  fafafa.ssl," \
  "demo_fluent_api must use the public facade unit alongside utility units"
require_fixed "$winssl_health_checker" "  fafafa.ssl;" \
  "winssl_health_checker must use the public facade unit"
require_fixed "$winssl_rest_client" "  fafafa.ssl;" \
  "winssl_rest_client must use the public facade unit"
require_fixed "$tcp_helper" "  fafafa.ssl;" \
  "fafafa.examples.tcp must use the public facade unit"
require_fixed "$real_world_test" "  fafafa.ssl," \
  "real_world_test must use the public facade unit alongside helper units"

for file in \
  "$https_rest_client" \
  "$certificate_chain" \
  "$demo_fluent_api" \
  "$winssl_health_checker" \
  "$winssl_rest_client" \
  "$tcp_helper" \
  "$real_world_test"; do
  require_absent "$file" "nextpas.core.tls.base" \
    "$file must stop teaching direct base-unit imports in active examples"
  require_absent "$file" "nextpas.core.tls.factory" \
    "$file must stop teaching direct factory-unit imports in active examples"
done

echo "[PASS] active examples public import truth contract passed"
