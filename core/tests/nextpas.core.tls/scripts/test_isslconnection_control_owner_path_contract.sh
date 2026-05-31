#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
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

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"
builder_file="src/nextpas.core.tls.connection.builder.pas"
tls_file="src/nextpas.core.tls.tls.pas"
api_ref="docs/reference/API_REFERENCE.md"
design_v2="docs/reference/INTERFACE_DESIGN_V2.md"
architecture_doc="docs/ARCHITECTURE.md"
audit_doc="docs/test_reports/INTERFACE_DESIGN_AUDIT_V1.5.0.md"
contract_src="tests/contract/test_connector_timeout_safety_entry.pas"
build_root="tmp/test_isslconnection_control_owner_path"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_connector_timeout_safety_entry"

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
require_fixed "$api_ref" "ISSLConnectionControl = interface" \
  "API reference must publish ISSLConnectionControl as the timeout/blocking owner path"
require_fixed "$api_ref" '连接创建后若需要读取或覆盖 runtime control state，新代码优先通过 `ISSLConnectionControl`。' \
  "API reference must describe ISSLConnectionControl as the runtime control owner path"
require_fixed "$design_v2" '├── ISSLConnectionControl (timeout / blocking 控制)' \
  "INTERFACE_DESIGN_V2 must include ISSLConnectionControl in the hierarchy"
require_fixed "$design_v2" '| SetTimeout, GetTimeout | ISSLConnectionControl | 默认 owner 已切到 ISSLConnectionControl；core 侧继续作为 `v1.x` convenience mirror 保留 |' \
  "INTERFACE_DESIGN_V2 must migrate timeout access to ISSLConnectionControl"
require_fixed "$architecture_doc" '当前 shipped source 对 timeout / blocking 这组 runtime control state 已补上 `ISSLConnectionControl` owner path；' \
  "ARCHITECTURE must describe the new timeout/blocking owner path"
require_fixed "$audit_doc" 'timeout / blocking 当前已有 `ISSLConnectionControl` owner path；' \
  "audit report must record that timeout/blocking now have an owner path"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "focused control owner-path contract source must compile"
fi

"$binary"

printf '[PASS] ISSLConnection control owner-path contract passed\n'
