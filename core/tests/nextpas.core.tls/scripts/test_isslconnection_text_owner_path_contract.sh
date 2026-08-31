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

printf '[TEST] ISSLConnection text owner-path contract\n'

require_fixed "$base_file" "ISSLConnectionTextIO = interface" \
  "base source must declare ISSLConnectionTextIO"
require_fixed "$base_file" "@owner-note 当前默认 text-helper owner 为 ISSLConnectionTextIO.ReadString；此入口继续作为 v1.x convenience-core mirror 保留" \
  "base source must classify ReadString around the ISSLConnectionTextIO owner path"
require_fixed "$base_file" "@owner-note 当前默认 text-helper owner 为 ISSLConnectionTextIO.WriteString；此入口继续作为 v1.x convenience-core mirror 保留" \
  "base source must classify WriteString around the ISSLConnectionTextIO owner path"
require_fixed "$conn_base_file" "ISSLConnectionTextIO," \
  "TBaseSSLConnection must implement ISSLConnectionTextIO"


printf '[PASS] ISSLConnection text owner-path contract passed\n'
