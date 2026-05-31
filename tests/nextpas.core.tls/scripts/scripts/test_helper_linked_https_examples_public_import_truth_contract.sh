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

server_common="examples/https_server/https_server_common.pas"
server_simple="examples/https_server/https_server_simple.pas"
server_alpn="examples/https_server/https_server_alpn.pas"
server_mtls="examples/https_server/https_server_mtls.pas"
client_session="examples/https_client/https_client_session.pas"

echo "[TEST] helper-linked https examples public import truth contract"

require_fixed "$server_common" "  fafafa.ssl;" \
  "https_server_common must use the public facade unit"
require_fixed "$server_simple" "  fafafa.ssl," \
  "https_server_simple must use the public facade unit alongside its helper"
require_fixed "$server_simple" "  https_server_common;" \
  "https_server_simple must keep the server helper unit"
require_fixed "$server_alpn" "  fafafa.ssl," \
  "https_server_alpn must use the public facade unit alongside its helper"
require_fixed "$server_alpn" "  https_server_common;" \
  "https_server_alpn must keep the server helper unit"
require_fixed "$server_mtls" "  fafafa.ssl," \
  "https_server_mtls must use the public facade unit alongside its helper"
require_fixed "$server_mtls" "  https_server_common;" \
  "https_server_mtls must keep the server helper unit"
require_fixed "$client_session" "  fafafa.ssl," \
  "https_client_session must use the public facade unit alongside its helper"
require_fixed "$client_session" "  fafafa.examples.tcp;" \
  "https_client_session must keep the TCP helper unit"

for file in \
  "$server_common" \
  "$server_simple" \
  "$server_alpn" \
  "$server_mtls" \
  "$client_session"; do
  require_absent "$file" "nextpas.core.tls.base" \
    "$file must stop teaching direct base-unit imports in helper-linked https examples"
  require_absent "$file" "nextpas.core.tls.factory" \
    "$file must stop teaching direct factory-unit imports in helper-linked https examples"
done

echo "[PASS] helper-linked https examples public import truth contract passed"
