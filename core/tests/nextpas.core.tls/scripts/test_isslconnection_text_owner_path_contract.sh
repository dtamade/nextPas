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
facade_file="src/nextpas.core.tls.pas"
api_ref="docs/reference/API_REFERENCE.md"
design_v2="docs/reference/INTERFACE_DESIGN_V2.md"
architecture_doc="docs/ARCHITECTURE.md"
audit_doc="docs/test_reports/INTERFACE_DESIGN_AUDIT_V1.5.0.md"
contract_src="tests/contract/test_isslconnection_text_owner_entry.pas"
build_root="tmp/test_isslconnection_text_owner_path"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_isslconnection_text_owner_entry"

printf '[TEST] ISSLConnection text owner-path contract\n'

require_fixed "$base_file" "ISSLConnectionTextIO = interface" \
  "base source must declare ISSLConnectionTextIO"
require_fixed "$base_file" "@owner-note 当前默认 text-helper owner 为 ISSLConnectionTextIO.ReadString；此入口继续作为 v1.x convenience-core mirror 保留" \
  "base source must classify ReadString around the ISSLConnectionTextIO owner path"
require_fixed "$base_file" "@owner-note 当前默认 text-helper owner 为 ISSLConnectionTextIO.WriteString；此入口继续作为 v1.x convenience-core mirror 保留" \
  "base source must classify WriteString around the ISSLConnectionTextIO owner path"
require_fixed "$conn_base_file" "ISSLConnectionTextIO," \
  "TBaseSSLConnection must implement ISSLConnectionTextIO"
require_fixed "$facade_file" "ISSLConnectionTextIO = nextpas.core.tls.base.ISSLConnectionTextIO;" \
  "main facade must re-export ISSLConnectionTextIO"
require_fixed "$api_ref" "ISSLConnectionTextIO = interface" \
  "API reference must publish ISSLConnectionTextIO"
require_fixed "$api_ref" '对 `ReadString` / `WriteString` 这组文本 helper，新代码若在连接创建后仍要沿用这层文本语义，优先通过 `ISSLConnectionTextIO`。' \
  "API reference must describe ISSLConnectionTextIO as the text-helper owner path"
require_fixed "$design_v2" '├── ISSLConnectionTextIO (文本 helper owner)' \
  "INTERFACE_DESIGN_V2 must include ISSLConnectionTextIO in the hierarchy"
require_fixed "$design_v2" '| ReadString, WriteString | ISSLConnectionTextIO | 默认 owner 已切到 ISSLConnectionTextIO；core 侧继续作为 `v1.x` convenience mirror 保留 |' \
  "INTERFACE_DESIGN_V2 must migrate text helpers to ISSLConnectionTextIO"
require_fixed "$architecture_doc" '├─ ISSLConnectionTextIO    (文本 helper owner)' \
  "ARCHITECTURE interface graph must include ISSLConnectionTextIO"
require_fixed "$architecture_doc" '`ISSLConnectionTextIO`：text helper owner；框架/transport 集成仍优先使用 `Read` / `Write`' \
  "ARCHITECTURE must classify ISSLConnectionTextIO as the text-helper owner"
require_fixed "$audit_doc" 'text helper 当前也已补上 `ISSLConnectionTextIO` owner path；' \
  "audit report must record the new text-helper owner path"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "focused text owner-path contract source must compile"
fi

"$binary"

printf '[PASS] ISSLConnection text owner-path contract passed\n'
