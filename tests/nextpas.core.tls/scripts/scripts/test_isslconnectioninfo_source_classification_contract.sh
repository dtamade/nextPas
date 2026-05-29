#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"

declare -a required_base_patterns=(
  "@compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLConnectionInfo"
  "承接 "
  "ISSLConnection"
  "这组 v1.x compatibility-core mirrors："
  "- GetConnectionInfo"
  "- GetContext"
  "- GetSelectedALPNProtocol"
  "- GetStateString"
  "这是当前 Stage-A demotion target"
)

for pattern in "${required_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$base_file"; then
    echo "[FAIL] source truth missing ISSLConnectionInfo classification note: $pattern"
    exit 1
  fi
done

declare -a required_conn_base_patterns=(
  "- ISSLConnectionInfo: 连接信息 / compatibility-core mirrors"
  "当前同时存在于 "
  "ISSLConnection"
  "ISSLConnectionInfo"
  "属于 v1.x compatibility-core"
  "Stage-A demotion target 已固定为 "
  "ISSLConnectionInfo)"
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing source-facing classification note: $pattern"
    exit 1
  fi
done

echo "[PASS] source classification for ISSLConnectionInfo mirrors matches the Stage-A roadmap"
