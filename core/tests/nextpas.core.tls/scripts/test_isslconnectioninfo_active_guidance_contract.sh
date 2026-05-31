#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_doc="docs/reference/API_REFERENCE.md"
integration_doc="docs/INTEGRATION_GUIDE.md"

declare -a forbidden_api_patterns=(
  "LInfo := LConn.GetConnectionInfo;"
  "WriteLn('ALPN: ', LConn.GetSelectedALPNProtocol);"
  "WriteLn('状态: ', LConn.GetStateString);"
)

for pattern in "${forbidden_api_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API reference still teaches direct core mirror usage: $pattern"
    exit 1
  fi
done

declare -a required_api_patterns=(
  "LConnInfoAccess: ISSLConnectionInfo;"
  "Supports(LConn, ISSLConnectionInfo, LConnInfoAccess)"
  "LInfo := LConnInfoAccess.GetConnectionInfo;"
  "WriteLn('ALPN: ', LConnInfoAccess.GetSelectedALPNProtocol);"
  "WriteLn('状态: ', LConnInfoAccess.GetStateString);"
  "如果你在写新代码，并且需要连接信息 / 上下文引用 / ALPN / 状态字符串这组 mirrors"
)

for pattern in "${required_api_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API reference missing ISSLConnectionInfo-first guidance: $pattern"
    exit 1
  fi
done

declare -a forbidden_integration_patterns=(
  "WriteLn('Selected ALPN: ', Conn.GetSelectedALPNProtocol);"
  "- Conn.GetStateString（后端相关的状态描述）"
)

for pattern in "${forbidden_integration_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$integration_doc"; then
    echo "[FAIL] integration guide still teaches direct core mirror usage: $pattern"
    exit 1
  fi
done

declare -a required_integration_patterns=(
  "var ConnInfo: ISSLConnectionInfo;"
  "if Supports(Conn, ISSLConnectionInfo, ConnInfo) then"
  "WriteLn('Selected ALPN: ', ConnInfo.GetSelectedALPNProtocol);"
  "ConnInfo.GetStateString"
)

for pattern in "${required_integration_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$integration_doc"; then
    echo "[FAIL] integration guide missing ISSLConnectionInfo-first guidance: $pattern"
    exit 1
  fi
done

echo "[PASS] active docs prefer ISSLConnectionInfo for connection-info mirrors"
