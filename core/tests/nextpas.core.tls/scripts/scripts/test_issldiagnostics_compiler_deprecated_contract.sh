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

compare_file_list() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "[FAIL] $label mismatch"
    echo "[expected]"
    printf '%s\n' "$expected"
    echo "[actual]"
    printf '%s\n' "$actual"
    exit 1
  fi
}

echo "[TEST] ISSLDiagnostics compiler deprecation alignment"

expect_count \
  "$(count_declaration "function GetHealthStatus\\: TSSLHealthStatus;\\s*deprecated 'Use ISSLDiagnostics\\.GetHealthStatus';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetHealthStatus declaration"
expect_count \
  "$(count_declaration "function IsHealthy\\: Boolean;\\s*deprecated 'Use ISSLDiagnostics\\.IsHealthy';")" \
  "1" \
  "expected exactly one compiler-deprecated core IsHealthy declaration"
expect_count \
  "$(count_declaration "function GetDiagnosticInfo\\: TSSLDiagnosticInfo;\\s*deprecated 'Use ISSLDiagnostics\\.GetDiagnosticInfo';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetDiagnosticInfo declaration"
expect_count \
  "$(count_declaration "function GetPerformanceMetrics\\: TSSLPerformanceMetrics;\\s*deprecated 'Use ISSLDiagnostics\\.GetPerformanceMetrics';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetPerformanceMetrics declaration"

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLDiagnostics.GetHealthStatus 获取"
  "@owner-note 默认 owner 为 ISSLDiagnostics.GetHealthStatus；此入口仅兼容保留"
  "@preferred-access 新代码优先通过 ISSLDiagnostics.IsHealthy 获取"
  "@owner-note 默认 owner 为 ISSLDiagnostics.IsHealthy；此入口仅兼容保留"
  "@preferred-access 新代码优先通过 ISSLDiagnostics.GetDiagnosticInfo 获取"
  "@owner-note 默认 owner 为 ISSLDiagnostics.GetDiagnosticInfo；此入口仅兼容保留"
  "@preferred-access 新代码优先通过 ISSLDiagnostics.GetPerformanceMetrics 获取"
  "@owner-note 默认 owner 为 ISSLDiagnostics.GetPerformanceMetrics；此入口仅兼容保留"
)

for pattern in "${required_base_patterns[@]}"; do
  require_fixed "$base_file" "$pattern" \
    "base source missing diagnostics compatibility-mirror note: $pattern"
done

declare -a required_conn_base_patterns=(
  '`GetHealthStatus` / `IsHealthy` / `GetDiagnosticInfo` / `GetPerformanceMetrics`'
  'ordinary docs/tests 已转向 `ISSLDiagnostics` owner path'
  'direct core diagnostics 当前只剩 contract mirror proof'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  require_fixed "$conn_base_file" "$pattern" \
    "base connection class missing diagnostics residual note: $pattern"
done

declare -a required_api_patterns=(
  "function GetHealthStatus: TSSLHealthStatus; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLDiagnostics.GetHealthStatus"
  "function IsHealthy: Boolean; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLDiagnostics.IsHealthy"
  "function GetDiagnosticInfo: TSSLDiagnosticInfo; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLDiagnostics.GetDiagnosticInfo"
  "function GetPerformanceMetrics: TSSLPerformanceMetrics; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLDiagnostics.GetPerformanceMetrics"
)

for pattern in "${required_api_patterns[@]}"; do
  require_fixed "$api_ref" "$pattern" \
    "API reference no longer records diagnostics core getter as compiler-deprecated mirror: $pattern"
done

require_fixed "$v2_doc" \
  "| GetHealthStatus, IsHealthy | ISSLDiagnostics | 默认 owner 已切到 ISSLDiagnostics；core 侧仅兼容保留，源码声明已是编译期 deprecated |" \
  "V2 migration table no longer records compiler-deprecated diagnostics health mirror"
require_fixed "$v2_doc" \
  "| GetPerformanceMetrics | ISSLDiagnostics | 默认 owner 已切到 ISSLDiagnostics；core 侧仅兼容保留，源码声明已是编译期 deprecated |" \
  "V2 migration table no longer records compiler-deprecated diagnostics metrics mirror"
require_fixed "$v2_doc" \
  "| GetDiagnosticInfo | ISSLDiagnostics | 默认 owner 已切到 ISSLDiagnostics；core 侧仅兼容保留，源码声明已是编译期 deprecated |" \
  "V2 migration table no longer records compiler-deprecated diagnostics diagnostic-info mirror"
require_fixed "$v2_doc" \
  "其中 \`GetHealthStatus\` / \`IsHealthy\` / \`GetDiagnosticInfo\` / \`GetPerformanceMetrics\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`；后续仍可再评估是否进一步完全收窄到 \`ISSLDiagnostics\` owner surface。" \
  "V2 migration note no longer records compiler-deprecated diagnostics fallback"

require_fixed "$backend_contract" \
  "LCoreHealth := LConn.GetHealthStatus;" \
  "backend contract lost the expected direct core GetHealthStatus mirror proof"
require_fixed "$backend_contract" \
  "LCorePerf := LConn.GetPerformanceMetrics;" \
  "backend contract lost the expected direct core GetPerformanceMetrics mirror proof"
require_fixed "$backend_contract" \
  "LCoreDiagInfo := LConn.GetDiagnosticInfo;" \
  "backend contract lost the expected direct core GetDiagnosticInfo mirror proof"
require_fixed "$backend_contract" \
  "LDiag.IsHealthy <> LConn.IsHealthy" \
  "backend contract lost the expected direct core IsHealthy mirror proof"
require_fixed "$backend_contract" \
  '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' \
  "backend contract missing diagnostics deprecation warning quarantine"

residual_hits="$(rg -lP '\b(?:Conn|LConn|LConnection|AConn)\.(?:GetHealthStatus|IsHealthy|GetDiagnosticInfo|GetPerformanceMetrics)\b' tests --glob '!tests/scripts/**' | sort || true)"
compare_file_list "diagnostics direct-core residual file set" \
  "$residual_hits" \
  "$(cat <<'EOF'
tests/contract/test_backend_contract.pas
EOF
)"

for file in \
  "tests/contract/test_backend_contract.pas"; do
  require_fixed "$file" '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' \
    "missing diagnostics deprecation warning quarantine in $file"
done

echo "[PASS] ISSLDiagnostics compiler deprecation is aligned across source, docs, and residual mirror proofs"
