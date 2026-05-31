#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

api_ref="docs/reference/API_REFERENCE.md"
facade_file="src/nextpas.core.tls.pas"
factory_file="src/nextpas.core.tls.factory.pas"
readme_file="README.md"

echo "[TEST] helper surface classification truth contract"

require_fixed "$readme_file" 'deprecated 顶层 helper aliases/functions 已移除；TLS 建立流程统一推荐走 `TSSLFactory.*` / `TSSLConnector` 主路径。' \
  "README must distinguish removed deprecated top-level helper aliases/functions from the current TLS bootstrap entry"
require_fixed "$readme_file" '显式 `TSSLHelper` 类与 `QuickServer(...)` / `CreateOCSPClient(...)` / `CreateCRLManager(...)` 这组 convenience helpers 仍然保留。' \
  "README must state that shipped convenience helpers still remain available"
require_absent "$readme_file" "deprecated helper API 已移除" \
  "README must stop implying that the entire helper surface was removed"

require_fixed "$factory_file" "TSSLHelper - 证书/随机/early-data 便捷辅助类；不作为 TLS bootstrap 主入口" \
  "factory source must classify TSSLHelper as a convenience helper surface"
require_fixed "$facade_file" "便捷API（仍然 shipped，但不替代 TSSLFactory / TSSLConnector 主入口）" \
  "main facade must classify the exported convenience helpers as non-primary entrypoints"
require_fixed "$facade_file" "快速创建服务端 context（只返回配置好的 ISSLContext；socket bind/listen/accept 仍由应用层负责）" \
  "QuickServer source comment must record its context-only bootstrap boundary"
require_fixed "$facade_file" "OCSP/CRL 证书工具 facade re-export（非 TLS bootstrap 入口）" \
  "facade source must classify OCSP/CRL helpers as certificate-tooling reexports"

require_fixed "$api_ref" '`TSSLFactory.GetLibraryInstance(...)` / `TSSLConnector` / `TSSLAcceptor` / `TSSLStream` 仍是当前 TLS bootstrap 主入口。' \
  "API reference must keep the current TLS bootstrap main-entry truth"
require_fixed "$api_ref" '`CreateDefaultConfig(...)` 当前只是 fresh default-config convenience helper。' \
  "API reference must classify CreateDefaultConfig as a convenience helper"
require_fixed "$api_ref" '`TSSLHelper` 当前保留为证书文件检查 / 随机与摘要工具 / early-data optional-interface convenience helper。' \
  "API reference must classify TSSLHelper as a convenience helper"
require_fixed "$api_ref" '它不代替 `TSSLFactory` / `TSSLContextBuilder` / `TSSLConnector` 这条主入口。' \
  "API reference must prevent TSSLHelper from being taught as a bootstrap entry"
require_fixed "$api_ref" '`QuickServer(...)` 当前只是 `TSSLFactory.CreateServerContext(...)` 的 convenience bootstrap。' \
  "API reference must classify QuickServer as a convenience bootstrap"
require_fixed "$api_ref" '它只返回配置好的 `ISSLContext`，不负责 socket bind/listen/accept。' \
  "API reference must record the QuickServer socket-boundary truth"
require_fixed "$api_ref" '`CreateOCSPClient(...)` / `CreateCRLManager(...)` 当前是证书工具 facade re-export，不是 TLS 连接/bootstrap 入口。' \
  "API reference must classify OCSP/CRL facade exports as certificate-tooling helpers"
require_fixed "$api_ref" '`TSSLEnterpriseConfig` 当前 helper 主路径是 `IsFIPSEnabled` / `GetTrustedRoots` / `GetAllPolicies`。' \
  "API reference must use the current TSSLEnterpriseConfig helper names"
require_fixed "$api_ref" '`IsFIPSModeEnabled(...)` / `GetEnterpriseTrustedRoots(...)` 仍然存在，但当前只应视为 legacy convenience wrappers。' \
  "API reference must demote old WinSSL enterprise globals to convenience wrappers"
require_absent "$api_ref" "function IsFIPSModeEnabled: Boolean;" \
  "API reference must stop presenting IsFIPSModeEnabled as the primary WinSSL enterprise helper signature"
require_absent "$api_ref" "function GetEnterpriseTrustedRoots: TStringArray;" \
  "API reference must stop presenting GetEnterpriseTrustedRoots as the primary WinSSL enterprise helper signature"

echo "[PASS] helper surface classification truth contract passed"
