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
  'direct core session-resumption 当前只剩 contract mirror proof'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  require_fixed "$conn_base_file" "$pattern" \
    "base connection class missing session-resumption residual note: $pattern"
done





echo "[PASS] ISSLSessionResumption compiler deprecation is aligned across source, docs, and contract mirror proofs"
