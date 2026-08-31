#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

base_file="core/src/nextpas.core.tls.base.pas"
conn_base_file="core/src/nextpas.core.tls.connection.base.pas"
builder_file="core/src/nextpas.core.tls.connection.builder.pas"
tls_file="core/src/nextpas.core.tls.tls.pas"

printf '[TEST] ISSLConnection control owner-path contract\n'

require_fixed "$base_file" "ISSLConnectionControl = interface" \
  "base source must declare ISSLConnectionControl"
require_fixed "$base_file" "@owner-note 当前 runtime connection-control state 的默认 owner 为 ISSLConnectionControl；" \
  "base source must classify timeout/blocking around ISSLConnectionControl owner notes"
require_fixed "$conn_base_file" "ISSLConnectionControl," \
  "TBaseSSLConnection must implement ISSLConnectionControl"
require_fixed "$builder_file" "Supports(AConnection, ISSLConnectionControl, LConnectionControl)" \
  "connection builder must prefer ISSLConnectionControl when applying runtime overrides"
require_fixed "$tls_file" "Supports(AConn, ISSLConnectionControl, LConnectionControl)" \
  "TLS facade must prefer ISSLConnectionControl when applying runtime overrides"


printf '[PASS] ISSLConnection control owner-path contract passed\n'
