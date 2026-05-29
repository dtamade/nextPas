#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_file="$root_dir/src/nextpas.core.tls.winssl.lib.pas"
platform_doc="$root_dir/docs/PLATFORM_SUPPORT.md"
winssl_design="$root_dir/docs/reference/WINSSL_DESIGN.md"
winssl_guide="$root_dir/docs/guides/WINSSL_USER_GUIDE.md"
winssl_matrix="$root_dir/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
api_ref="$root_dir/docs/reference/API_REFERENCE.md"
migration_guide="$root_dir/docs/guides/MIGRATION_GUIDE.md"
user_guide="$root_dir/docs/guides/USER_GUIDE.md"
troubleshooting="$root_dir/docs/guides/TROUBLESHOOTING.md"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_present() {
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

# BACKEND_ABSTRACTION_LAYER_DESIGN.md and BACKEND_SELECTOR_DESIGN.md were refactored
# to no longer maintain capability tables (they now defer to docs/BACKEND_CAPABILITY_MATRIX.md).
# FIPS truth assertions now check docs/PLATFORM_SUPPORT.md and other active docs.

require_absent "$platform_doc" "| **FIPS 模式** | 支持                | 支持         |" \
  "Platform support doc still markets OpenSSL default-build FIPS support"
require_absent "$platform_doc" "| **FIPS 模式** | 默认构建不发布      | 支持         |" \
  "Platform support doc still markets WinSSL FIPS capability as published truth"
require_present "$platform_doc" "| **FIPS 模式** | 默认构建不发布      | 当前 capability 不发布 |" \
  "Platform support doc no longer records the current OpenSSL/WinSSL FIPS truth"
require_present "$platform_doc" "OpenSSL 若要进入 FIPS 路线，需要额外的专门模块/构建；当前 fafafa.ssl 默认 OpenSSL backend capability 仍为未发布。" \
  "Platform support doc no longer records the current OpenSSL FIPS note"
require_present "$platform_doc" 'WinSSL 目前可检测/遵循 Windows FIPS policy，但 `SupportsFIPSMode` 仍未作为当前 backend capability 发布。' \
  "Platform support doc no longer records the WinSSL FIPS helper-vs-capability boundary"

require_absent "$source_file" "Result.SupportsFIPSMode := True;" \
  "WinSSL library source still publishes FIPS capability as True"
require_present "$source_file" "Result.SupportsFIPSMode := False;" \
  "WinSSL library source no longer records the unpublished FIPS capability truth"

require_absent "$winssl_design" "- **FIPS 140-2**：在启用 FIPS 模式时自动合规" \
  "WinSSL design doc still markets system FIPS policy as published capability"
require_present "$winssl_design" '- **FIPS policy 检测**：可检测 Windows 是否启用 FIPS policy，但这不是当前公开 `SupportsFIPSMode` capability' \
  "WinSSL design doc no longer records the FIPS helper-vs-capability boundary"

require_absent "$winssl_guide" "| **FIPS 合规**    | ✅ 内置        | ⚠️ 需要特殊构建    |" \
  "WinSSL user guide still markets built-in FIPS capability"
require_present "$winssl_guide" "| **FIPS 合规**    | ⚠️ 系统策略检测/遵循 | ⚠️ 需要特殊构建    |" \
  "WinSSL user guide no longer records the current FIPS comparison truth"
require_present "$winssl_guide" '当前 `nextpas.core.tls.winssl.enterprise` 提供的是 Windows FIPS policy 检测 helper，不等于 `ISSLLibrary.GetCapabilities.SupportsFIPSMode=True`。' \
  "WinSSL user guide no longer records the FIPS helper-vs-capability boundary"

require_present "$winssl_matrix" "| FIPS policy / capability | 系统策略检测（不作为当前 capability 发布） | 库级 capability（需专门构建） |" \
  "WinSSL backend capability matrix no longer records the current FIPS comparison boundary"

require_present "$api_ref" '这些 WinSSL 企业 helper 当前提供的是 Windows FIPS policy / 企业证书 / GPO 检测能力，不等于 `ISSLLibrary.GetCapabilities.SupportsFIPSMode=True`。' \
  "API reference no longer records the WinSSL enterprise helper boundary"
require_present "$migration_guide" '`IsFIPSEnabled` 代表系统 policy/helper 检测，不等于当前 WinSSL backend 已发布 `SupportsFIPSMode=True`。' \
  "Migration guide no longer records that WinSSL enterprise FIPS helpers are not backend capability truth"
require_present "$user_guide" "// 注意：这只是 Windows policy/helper 检测，不等于当前 backend capability 已发布" \
  "User guide no longer records the WinSSL enterprise helper boundary"
require_present "$troubleshooting" "// 注意：这里只是在检查 Windows FIPS policy/helper 状态，不等于 backend capability 已发布" \
  "Troubleshooting guide no longer records the WinSSL enterprise helper boundary"

echo "[PASS] active FIPS docs remain aligned with current source truth"
