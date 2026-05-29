#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

file="docs/reference/WINSSL_PERFORMANCE_TUNING.md"

declare -a fixed_checks=(
  "(LConn1 as ISSLClientConnection).SetServerName('api.example.com');"
  "(LConn2 as ISSLClientConnection).SetServerName('api.example.com');"
  "// 假设 LConn1/LConn2 在创建时已经按 example.com 完成连接级 SNI 配置。"
  "// Acquire 返回的连接绑定到池的 FHost，并已完成连接级 SNI 配置。"
  "// AConn 在调用前应已完成连接级 SNI 配置。"
  "LHost := 'example.com';"
)

for needle in "${fixed_checks[@]}"; do
  if ! rg -n --fixed-strings --quiet "$needle" "$file"; then
    echo "[FAIL] missing connection-level SNI guidance in $file"
    echo "       expected line: $needle"
    exit 1
  fi
done

expected_literal_count=2
actual_literal_count="$(
  { rg -o --fixed-strings "(LConn as ISSLClientConnection).SetServerName('example.com');" "$file" || true; } | wc -l | tr -d ' '
)"

if [ "$actual_literal_count" -ne "$expected_literal_count" ]; then
  echo "[FAIL] unexpected count for memory-leak example SNI guidance in $file"
  echo "       expected count: $expected_literal_count"
  echo "       actual count:   $actual_literal_count"
  exit 1
fi

expected_host_count=3
actual_host_count="$(
  { rg -o --fixed-strings "(LConn as ISSLClientConnection).SetServerName(LHost);" "$file" || true; } | wc -l | tr -d ' '
)"

if [ "$actual_host_count" -ne "$expected_host_count" ]; then
  echo "[FAIL] unexpected count for benchmark SNI guidance in $file"
  echo "       expected count: $expected_host_count"
  echo "       actual count:   $actual_host_count"
  exit 1
fi

echo "[PASS] WinSSL performance tuning guide teaches connection-level SNI in selected client flows"
