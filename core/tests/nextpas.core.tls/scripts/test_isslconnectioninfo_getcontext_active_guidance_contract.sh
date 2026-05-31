#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_doc="docs/reference/API_REFERENCE.md"
capability_doc="docs/CAPABILITY_MATRIX_GUIDE.md"

declare -a forbidden_capability_patterns=(
  "Caps := Conn.GetContext.GetLibrary.GetCapabilities;"
)

for pattern in "${forbidden_capability_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$capability_doc"; then
    echo "[FAIL] capability guide still teaches direct core GetContext usage: $pattern"
    exit 1
  fi
done

declare -a required_capability_patterns=(
  "ConnInfo: ISSLConnectionInfo;"
  "Supports(Conn, ISSLConnectionInfo, ConnInfo)"
  "Caps := ConnInfo.GetContext.GetLibrary.GetCapabilities;"
)

for pattern in "${required_capability_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$capability_doc"; then
    echo "[FAIL] capability guide missing ISSLConnectionInfo-first GetContext guidance: $pattern"
    exit 1
  fi
done

declare -a required_api_patterns=(
  "如果你在写新代码，并且需要连接信息 / 上下文引用 / ALPN / 状态字符串这组 mirrors"
)

for pattern in "${required_api_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API reference missing ISSLConnectionInfo-first GetContext note: $pattern"
    exit 1
  fi
done

echo "[PASS] active docs de-emphasize core GetContext in favor of ISSLConnectionInfo"
