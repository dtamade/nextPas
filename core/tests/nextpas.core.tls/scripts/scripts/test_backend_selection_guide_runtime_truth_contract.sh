#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
guide="$root_dir/docs/BACKEND_SELECTION_GUIDE.md"

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

require_present "$guide" '注意：`WithSecurityFirst` 会优先满足 TLS 1.3、现代密码套件与安全评分；它本身不等于默认已进入 FIPS 路线。' \
  "Backend selection guide no longer records that WithSecurityFirst is not a default FIPS shortcut"
require_present "$guide" '要求当前已发布 PKCS#11 capability；若当前没有任何已注册 backend 发布 `SupportsPKCS11=True`，自动选择会失败。' \
  "Backend selection guide no longer records the runtime-aware PKCS#11 requirement boundary"
require_present "$guide" "在 OpenSSL 路径下，这又取决于 Provider / ENGINE runtime surface readiness。" \
  "Backend selection guide no longer records the OpenSSL PKCS#11 runtime note"
require_present "$guide" ".RequirePKCS11Support                   // 3. PKCS#11（取决于当前 runtime-aware capability）" \
  "Backend selection guide no longer marks the chain example with runtime-aware PKCS#11 wording"
require_present "$guide" "注意：这段代码表达的是需求，不保证当前默认 shipped backends 一定能自动满足。" \
  "Backend selection guide no longer records the scenario-level requirement-vs-availability warning"
require_present "$guide" "OpenSSL 默认构建 capability 不发布 FIPS，WinSSL 当前 capability 不发布 PKCS#11；如需这条路线，必须先准备专门 OpenSSL FIPS 模块/构建，并确认 PKCS#11 runtime surface 已发布。" \
  "Backend selection guide no longer records the current FIPS + PKCS#11 deployment boundary"

echo "[PASS] backend selection guide remains aligned with current runtime-aware truth"
