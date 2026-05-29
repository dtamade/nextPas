#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_doc="docs/reference/API_DOCUMENTATION.md"

declare -a forbidden_api_patterns=(
  "if Connection.GetOCSPStaplingEnabled then"
  "OCSPResponse := Connection.GetOCSPResponse;"
  "if Connection.IsOCSPResponseVerified then"
  "WriteLn('OCSP 状态: ', Connection.GetOCSPResponseStatus);"
)

for pattern in "${forbidden_api_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API documentation still teaches direct core OCSP usage: $pattern"
    exit 1
  fi
done

declare -a required_api_patterns=(
  "OCSP: ISSLOCSPStapling;"
  "if Supports(Connection, ISSLOCSPStapling, OCSP) and OCSP.GetOCSPStaplingEnabled then"
  "OCSPResponse := OCSP.GetOCSPResponse;"
  "if Supports(Connection, ISSLOCSPStapling, OCSP) and OCSP.IsOCSPResponseVerified then"
  "WriteLn('OCSP 状态: ', OCSP.GetOCSPResponseStatus);"
  '下面这组 `GetOCSP*` 条目之所以仍保留在 `ISSLConnection` 小节，是因为当前 shipped source 仍向后兼容这些 compatibility-core mirrors。'
  '新代码优先通过 `ISSLOCSPStapling` 读取 stapling 状态 / response / verify status / status string。'
  '优先通过 `ISSLOCSPStapling.GetOCSPStaplingEnabled`'
  '优先通过 `ISSLOCSPStapling.GetOCSPResponse`'
  '优先通过 `ISSLOCSPStapling.IsOCSPResponseVerified`'
  '优先通过 `ISSLOCSPStapling.GetOCSPResponseStatus`'
)

for pattern in "${required_api_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API documentation missing ISSLOCSPStapling-first guidance: $pattern"
    exit 1
  fi
done

echo "[PASS] active docs prefer ISSLOCSPStapling for OCSP stapling surfaces"
