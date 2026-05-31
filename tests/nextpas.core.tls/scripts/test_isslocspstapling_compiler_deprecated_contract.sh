#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"

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

expect_count \
  "$(count_declaration "function GetOCSPStaplingEnabled\\: Boolean;\\s*deprecated 'Use ISSLOCSPStapling\\.GetOCSPStaplingEnabled';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetOCSPStaplingEnabled declaration"
expect_count \
  "$(count_declaration "function GetOCSPResponse\\: TBytes;\\s*deprecated 'Use ISSLOCSPStapling\\.GetOCSPResponse';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetOCSPResponse declaration"
expect_count \
  "$(count_declaration "function IsOCSPResponseVerified\\: Boolean;\\s*deprecated 'Use ISSLOCSPStapling\\.IsOCSPResponseVerified';")" \
  "1" \
  "expected exactly one compiler-deprecated core IsOCSPResponseVerified declaration"
expect_count \
  "$(count_declaration "function GetOCSPResponseStatus\\: string;\\s*deprecated 'Use ISSLOCSPStapling\\.GetOCSPResponseStatus';")" \
  "1" \
  "expected exactly one compiler-deprecated core GetOCSPResponseStatus declaration"

declare -a required_api_patterns=(
  "function GetOCSPStaplingEnabled: Boolean; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLOCSPStapling.GetOCSPStaplingEnabled"
  "function GetOCSPResponse: TBytes; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLOCSPStapling.GetOCSPResponse"
  "function IsOCSPResponseVerified: Boolean; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLOCSPStapling.IsOCSPResponseVerified"
  "function GetOCSPResponseStatus: string; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLOCSPStapling.GetOCSPResponseStatus"
  "\`GetOCSPStaplingEnabled\` / \`GetOCSPResponse\` / \`IsOCSPResponseVerified\` / \`GetOCSPResponseStatus\` 在 \`ISSLConnection\` 上当前也只作为 \`v1.x\` compatibility-core mirrors 保留；当前源码声明已经是编译期 \`deprecated\`，需要 stapled OCSP runtime state 时，新代码优先通过 \`ISSLOCSPStapling\` owner surface 访问。"
)

for pattern in "${required_api_patterns[@]}"; do
  require_fixed "$api_ref" "$pattern" \
    "API reference no longer records OCSP core surface as compiler-deprecated mirror: $pattern"
done

require_fixed "$v2_doc" \
  "| GetOCSP* | ISSLOCSPStapling | 默认 owner 已切到 ISSLOCSPStapling；core 侧仅兼容保留，源码声明已是编译期 deprecated |" \
  "V2 migration table no longer records compiler-deprecated core GetOCSP* surface"
require_fixed "$v2_doc" \
  "其中 \`GetOCSPStaplingEnabled\` / \`GetOCSPResponse\` / \`IsOCSPResponseVerified\` / \`GetOCSPResponseStatus\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`；后续仍可再评估是否进一步完全收窄到 \`ISSLOCSPStapling\` owner surface。" \
  "V2 migration note no longer records compiler-deprecated OCSP fallback"

declare -A expected_suppression_counts=(
  ["tests/mbedtls/test_mbedtls_ocsp_capability.pas"]=1
  ["tests/openssl/test_ocsp_connection_verification_regression.pas"]=1
  ["tests/test_openssl_connection_ocsp_storectx_issuer_contract.pas"]=1
  ["tests/test_wolfssl_ocsp_stapling_contract.pas"]=1
)

for file in "${!expected_suppression_counts[@]}"; do
  expected="${expected_suppression_counts[$file]}"
  count=$(rg -F -c '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$file")
  if (( count < expected )); then
    echo "[FAIL] expected at least $expected OCSP deprecation warning suppressions in $file, found $count"
    exit 1
  fi
done

echo "[PASS] ISSLOCSPStapling compiler deprecation is aligned across source, docs, and intentional residual tests"
