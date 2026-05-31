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

client_auth="examples/production/https_client_auth.pas"
client_simple="examples/production/https_client_simple.pas"
client_post="examples/production/https_client_post.pas"
server_simple="examples/production/https_server_simple.pas"
client_session="examples/production/https_client_session.pas"

echo "[TEST] production https examples public import truth contract"

for file in \
  "$client_auth" \
  "$client_simple" \
  "$client_post" \
  "$client_session"; do
  require_fixed "$file" "  fafafa.ssl," \
    "$file must use the public facade unit alongside its helper"
  require_fixed "$file" "  fafafa.examples.tcp;" \
    "$file must keep the TCP helper unit"
done

require_fixed "$server_simple" "  fafafa.ssl;" \
  "https_server_simple must use the public facade unit"

for file in \
  "$client_auth" \
  "$client_simple" \
  "$client_post" \
  "$server_simple" \
  "$client_session"; do
  require_absent "$file" "nextpas.core.tls.base" \
    "$file must stop teaching direct base-unit imports in production https examples"
  require_absent "$file" "nextpas.core.tls.factory" \
    "$file must stop teaching direct factory-unit imports in production https examples"
done

echo "[PASS] production https examples public import truth contract passed"
