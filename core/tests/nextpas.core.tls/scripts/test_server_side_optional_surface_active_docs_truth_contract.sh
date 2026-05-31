#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_REF="$ROOT_DIR/docs/reference/API_REFERENCE.md"
BACKEND_MATRIX="$ROOT_DIR/docs/BACKEND_CAPABILITY_MATRIX.md"
WINSSL_MATRIX="$ROOT_DIR/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
MBEDTLS_MATRIX="$ROOT_DIR/docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md"
EARLY_DATA_GUIDE="$ROOT_DIR/docs/guides/EARLY_DATA_GUIDE.md"
OCSP_GUIDE="$ROOT_DIR/docs/guides/OCSP_USAGE_GUIDE.md"

fail() {
  echo "[FAIL] $1"
  exit 1
}

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    echo "[PASS] $message"
  else
    fail "$message"
  fi
}

echo "[TEST] server-side optional surface active-docs truth contract"

require_fixed "$API_REF" \
  "当前 public Pascal source 尚未声明 \`ISSLServerConnection\`；服务端特有能力主要通过可选 context 扩展接口暴露。" \
  "API reference must keep the current no-ISSLServerConnection truth"
require_fixed "$API_REF" \
  "ISSLServerOCSPStaplingContext = interface" \
  "API reference must declare ISSLServerOCSPStaplingContext"
require_fixed "$API_REF" \
  "ISSLEarlyDataContext = interface" \
  "API reference must declare ISSLEarlyDataContext"
require_fixed "$API_REF" \
  "ISSLEarlyDataConnection = interface" \
  "API reference must declare ISSLEarlyDataConnection"

require_fixed "$BACKEND_MATRIX" \
  "**状态**: ⚠️ 实验性支持（public surface 已接通，默认 shipped path 已切到本地持久化 replay-store 路径）" \
  "Top-level matrix must keep FreePascal early-data durable experimental truth"
require_fixed "$BACKEND_MATRIX" \
  "**状态**: ✅ 完整支持（生产就绪，v1.4.1+）" \
  "Top-level matrix must keep OpenSSL early-data stable truth"
require_fixed "$BACKEND_MATRIX" \
  "当前后端不会暴露 \`ISSLEarlyDataContext\` 可选接口，避免调用方命中存根异常" \
  "Top-level matrix must keep MbedTLS early-data interface-absence truth"
require_fixed "$BACKEND_MATRIX" \
  "在上述 helper 缺失时，client context 不暴露 \`ISSLEarlyDataContext\`，client connection 也不暴露 \`ISSLEarlyDataConnection\`" \
  "Top-level matrix must keep WolfSSL helper-gated early-data interface truth"
require_fixed "$BACKEND_MATRIX" \
  "**状态**: ⚠️ 已暴露 public surface，capability 仍按 \`experimental\` 发布" \
  "Top-level matrix must keep FreePascal server-OCSP experimental public-surface truth"
require_fixed "$BACKEND_MATRIX" \
  "**状态**: ❌ 不支持当前仓库的 OCSP stapling public surface" \
  "Top-level matrix must keep WinSSL server-OCSP none-published truth"
require_fixed "$BACKEND_MATRIX" \
  "当前后端不会暴露 \`ISSLServerOCSPStaplingContext\`" \
  "Top-level matrix must keep MbedTLS server-OCSP interface-absence truth"
require_fixed "$BACKEND_MATRIX" \
  "✅ public optional context interface \`ISSLServerOCSPStaplingContext\`" \
  "Top-level matrix must keep WolfSSL server-OCSP public-surface truth"

require_fixed "$WINSSL_MATRIX" \
  "| OCSP Stapling | ❌ 当前 capability 不发布 | Schannel 可能存在系统级自动行为；但 fafafa.ssl 当前 \`OCSPStaplingSupport=sslSupportNone\`，且不暴露 \`ISSLServerOCSPStaplingContext\` |" \
  "WinSSL dedicated matrix must keep server-OCSP none-published truth"
require_fixed "$WINSSL_MATRIX" \
  "| 0-RTT          | ❌ 当前 capability 不发布 | Windows Schannel 可能存在 TLS 1.3 / early-data 平台潜力；但 fafafa.ssl 当前 \`EarlyDataSupport=sslSupportNone\`，且不暴露 \`ISSLEarlyDataContext\` |" \
  "WinSSL dedicated matrix must keep early-data none-published truth"

require_fixed "$MBEDTLS_MATRIX" \
  "| 0-RTT | ❌ 当前 capability 不发布 | 当前 backend 不暴露 ISSLEarlyDataContext / ISSLEarlyDataConnection public surface |" \
  "MbedTLS dedicated matrix must keep early-data none-published truth"

require_fixed "$EARLY_DATA_GUIDE" \
  "\`FreePascal\` 的 client/server surface 已接通，但能力仍按 experimental 发布；默认 replay truth 落到本地持久化 replay-store，默认路径不可用或不可写时 fail-closed reject。" \
  "Early-data guide must keep FreePascal durable-default truth"
require_fixed "$EARLY_DATA_GUIDE" \
  "\`WinSSL\` / \`MbedTLS\` 当前不支持 early-data，因此示例里的 \`Supports(...)\` 检查必须保留。" \
  "Early-data guide must keep WinSSL/MbedTLS unsupported truth"
require_fixed "$EARLY_DATA_GUIDE" \
  "则 capability 会退化为 \`none\`，context / connection 都不会暴露 early-data 接口。" \
  "Early-data guide must keep WolfSSL helper-gated none fallback truth"

require_fixed "$OCSP_GUIDE" \
  "如果 builder 配置了 \`server_ocsp_stapled_response_file\`，但 backend 不支持 \`ISSLServerOCSPStaplingContext\`，\`BuildServer\` 会直接报配置错误，不会 silent ignore。" \
  "OCSP guide must keep builder fail-fast truth for unsupported server OCSP backends"
require_fixed "$OCSP_GUIDE" \
  "这条路径只负责 caller-provided material，不负责 online fetch、refresh，或 responder 调度。" \
  "OCSP guide must keep caller-provided-material-only boundary"
require_fixed "$OCSP_GUIDE" \
  "\`ISSLServerOCSPStaplingContext\` 仍然是 server 侧 clear / set bytes / load file / has / get 的 public surface" \
  "OCSP guide must keep WolfSSL server-side optional surface truth"

echo "[PASS] server-side optional surface active-docs truth contract passed"
