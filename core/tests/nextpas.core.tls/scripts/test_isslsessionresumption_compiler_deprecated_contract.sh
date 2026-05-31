#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"
backend_contract="tests/contract/test_backend_contract.pas"

count_declaration() {
  local pattern="$1"
  perl -0ne "my \$n = () = /$pattern/g; print \$n;" "$base_file"
}

expect_count() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "[FAIL] $message"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    exit 1
  fi
}

require_fixed() {
  local file="$1"
  local text="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$text" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

echo "[TEST] ISSLSessionResumption compiler deprecation alignment"

expect_count \
  "$(count_declaration "function GetSession\\: ISSLSession;\\s*deprecated 'Use ISSLSessionResumption\\.GetSession';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetSession declaration"
expect_count \
  "$(count_declaration "procedure SetSession\\(ASession\\: ISSLSession\\);\\s*deprecated 'Use ISSLSessionResumption\\.SetSession';")" \
  "1" \
  "expected exactly one compiler-deprecated core SetSession declaration"
expect_count \
  "$(count_declaration "function IsSessionReused\\: Boolean;\\s*deprecated 'Use ISSLSessionResumption\\.IsSessionReused';")" \
  "1" \
  "expected exactly one compiler-deprecated core IsSessionReused declaration"

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLSessionResumption.GetSession 获取"
  "@owner-note 默认 owner 为 ISSLSessionResumption.GetSession；此入口仅兼容保留"
  "@preferred-access 新代码优先通过 ISSLSessionResumption.SetSession 配置待恢复会话"
  "@owner-note 默认 owner 为 ISSLSessionResumption.SetSession；此入口仅兼容保留"
  "@preferred-access 新代码优先通过 ISSLSessionResumption.IsSessionReused 判断握手是否实际复用"
  "@owner-note 默认 owner 为 ISSLSessionResumption.IsSessionReused；此入口仅兼容保留"
)

for pattern in "${required_base_patterns[@]}"; do
  require_fixed "$base_file" "$pattern" \
    "base source missing session-resumption compatibility-mirror note: $pattern"
done

declare -a required_conn_base_patterns=(
  '`GetSession` / `SetSession` / `IsSessionReused`'
  'ordinary docs/tests 已转向 `ISSLSessionResumption` owner path'
  'direct core session-resumption 当前只剩 contract mirror proof'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  require_fixed "$conn_base_file" "$pattern" \
    "base connection class missing session-resumption residual note: $pattern"
done

declare -a required_api_patterns=(
  "function GetSession: ISSLSession; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLSessionResumption.GetSession"
  "procedure SetSession(ASession: ISSLSession); // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLSessionResumption.SetSession"
  "function IsSessionReused: Boolean; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLSessionResumption.IsSessionReused"
  '`GetSession` / `SetSession` / `IsSessionReused` 在 `ISSLConnection` 上当前也只作为 `v1.x` compatibility-core mirror 保留；当前源码声明已经是编译期 `deprecated`，需要保存/恢复会话或读取复用命中结果时，新代码优先通过 `ISSLSessionResumption` owner surface 访问。'
)

for pattern in "${required_api_patterns[@]}"; do
  require_fixed "$api_ref" "$pattern" \
    "API reference no longer records session-resumption core surface as compiler-deprecated mirror: $pattern"
done

require_fixed "$v2_doc" \
  "| GetSession, SetSession | ISSLSessionResumption | 默认 owner 已切到 ISSLSessionResumption；core 侧仅兼容保留，源码声明已是编译期 deprecated |" \
  "V2 migration table no longer records compiler-deprecated GetSession/SetSession mirror"
require_fixed "$v2_doc" \
  "| IsSessionReused | ISSLSessionResumption | 默认 owner 已切到 ISSLSessionResumption；core 侧仅兼容保留，源码声明已是编译期 deprecated |" \
  "V2 migration table no longer records compiler-deprecated IsSessionReused mirror"
require_fixed "$v2_doc" \
  "其中 \`GetSession\` / \`SetSession\` / \`IsSessionReused\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`；后续仍可再评估是否进一步完全收窄到 \`ISSLSessionResumption\` owner surface。" \
  "V2 migration note no longer records compiler-deprecated session-resumption fallback"

require_fixed "$backend_contract" \
  "LCoreSession := LConn.GetSession;" \
  "backend contract lost the expected direct core GetSession mirror proof"
require_fixed "$backend_contract" \
  "LCoreReused := LConn.IsSessionReused;" \
  "backend contract lost the expected direct core IsSessionReused mirror proof"
require_fixed "$backend_contract" \
  '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' \
  "backend contract missing session-resumption deprecation warning quarantine"

echo "[PASS] ISSLSessionResumption compiler deprecation is aligned across source, docs, and contract mirror proofs"
