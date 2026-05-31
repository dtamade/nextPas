#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

require_absent() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

readme="README.md"
api_ref="docs/reference/API_REFERENCE.md"
troubleshooting="docs/guides/TROUBLESHOOTING.md"
mbedtls_guide="docs/guides/MBEDTLS_USER_GUIDE.md"
user_guide="docs/guides/USER_GUIDE.md"
winssl_best="docs/guides/WINSSL_BEST_PRACTICES.md"
winssl_quick="docs/guides/WINSSL_QUICKSTART.md"
winssl_user="docs/guides/WINSSL_USER_GUIDE.md"
zh_faq="docs/zh/FAQ.md"
zh_quickstart="docs/zh/快速入门.md"
zh_overview="docs/zh/API参考/概述.md"

printf '[TEST] active docs verify-mode guidance truth contract\n'

require_fixed "$readme" 'builder 上如果要禁用验证，请显式使用 `.WithVerifyNone`；' \
  "README must explain the builder-specific verify-disable entrypoint"
require_fixed "$readme" 'LConfig.VerifyMode := [];  // config/direct-context 当前 public no-verify 语义' \
  "README must explain config empty-set verify-mode semantics"

require_fixed "$api_ref" 'builder 上如果要禁用验证，请显式使用 `.WithVerifyNone`；' \
  "API reference must explain the builder-specific verify-disable entrypoint"
require_fixed "$api_ref" 'LConfig.VerifyMode := [];  // config/direct-context 当前 public no-verify 语义' \
  "API reference must explain config empty-set verify-mode semantics"

require_fixed "$troubleshooting" 'LContext.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "troubleshooting guide must explain direct-context versus builder verify-disable entrypoints"

require_absent "$mbedtls_guide" 'Context.SetVerifyMode([sslVerifyNone]);' \
  "MbedTLS guide must stop teaching [sslVerifyNone] as the active direct-context example"
require_fixed "$mbedtls_guide" 'Context.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "MbedTLS guide must use the current direct-context no-verify guidance"

require_fixed "$user_guide" 'LContext.SetVerifyMode([]); // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "user guide must explain direct-context versus builder verify-disable entrypoints"

require_fixed "$winssl_best" 'LContext.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "WinSSL best practices guide must explain direct-context versus builder verify-disable entrypoints"
require_fixed "$winssl_quick" 'Ctx.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "WinSSL quickstart must explain direct-context versus builder verify-disable entrypoints"
require_fixed "$winssl_user" 'Ctx.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "WinSSL user guide must explain direct-context versus builder verify-disable entrypoints"

require_absent "$zh_faq" 'LContext.SetVerifyMode([sslVerifyNone]);' \
  "Chinese FAQ must stop teaching [sslVerifyNone] as the active direct-context example"
require_fixed "$zh_faq" 'LContext.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "Chinese FAQ must use the current direct-context no-verify guidance"

require_absent "$zh_quickstart" 'LContext.SetVerifyMode([sslVerifyNone]);' \
  "Chinese quickstart must stop teaching [sslVerifyNone] as the active direct-context example"
require_fixed "$zh_quickstart" 'LContext.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "Chinese quickstart must use the current direct-context no-verify guidance"

require_absent "$zh_overview" 'LContext.SetVerifyMode([sslVerifyNone]);' \
  "Chinese API overview must stop teaching [sslVerifyNone] as the active direct-context example"
require_fixed "$zh_overview" 'LContext.SetVerifyMode([]);  // 当前 direct-context no-verify 入口；builder 请改用 WithVerifyNone' \
  "Chinese API overview must use the current direct-context no-verify guidance"

printf '[PASS] active docs verify-mode guidance truth contract passed\n'
