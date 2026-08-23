#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"
conn_base_file="core/src/nextpas.core.tls.connection.base.pas"

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
  'direct core diagnostics 当前只剩 contract mirror proof'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  require_fixed "$conn_base_file" "$pattern" \
    "base connection class missing diagnostics residual note: $pattern"
done





residual_hits="$(rg -lP '\b(?:Conn|LConn|LConnection|AConn)\.(?:GetHealthStatus|IsHealthy|GetDiagnosticInfo|GetPerformanceMetrics)\b' core/tests/nextpas.core.tls --glob '!**/scripts/**' | sort || true)"
compare_file_list "diagnostics direct-core residual file set" \
  "$residual_hits" \
  ""

echo "[PASS] ISSLDiagnostics compiler deprecation is aligned across source, docs, and residual mirror proofs"
