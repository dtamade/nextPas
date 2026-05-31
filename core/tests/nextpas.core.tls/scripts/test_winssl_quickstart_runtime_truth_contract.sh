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

quickstart="docs/guides/WINSSL_QUICKSTART.md"

echo "[TEST] WinSSL quickstart runtime truth contract"

require_fixed "$quickstart" "Ctx.SetVerifyMode([sslVerifyPeer]);" \
  "WinSSL quickstart must use the current verify-peer set syntax"
require_fixed "$quickstart" "Ctx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);" \
  "WinSSL quickstart must keep the current mTLS verify-mode syntax"
require_fixed "$quickstart" "Ctx.LoadCAFile('custom-ca.crt');" \
  "WinSSL quickstart must keep the current custom CA loading path"
require_fixed "$quickstart" "WriteLn('SNI hostname: ', (Conn as ISSLClientConnection).GetServerName);" \
  "WinSSL quickstart must use per-connection SNI inspection in troubleshooting"
require_fixed "$quickstart" "证书验证失败（例如 CA、hostname 或 mTLS 策略不匹配）" \
  "WinSSL quickstart must describe certificate verification as a current runtime path"

require_absent "$quickstart" "Ctx.SetVerifyMode(sslVerifyPeer);" \
  "WinSSL quickstart must stop using stale non-set verify syntax"
require_absent "$quickstart" "Ctx.SetVerifyMode(sslVerifyPeer or sslVerifyFailIfNoPeerCert);" \
  "WinSSL quickstart must stop using stale bitwise verify syntax"
require_absent "$quickstart" "// ⏳ 待实现" \
  "WinSSL quickstart must stop marking shipped verify/mTLS/CA paths as pending"
require_absent "$quickstart" "证书验证失败（未实现时使用手动模式）" \
  "WinSSL quickstart must stop describing verification as unimplemented"
require_absent "$quickstart" "WriteLn('SNI hostname: ', Ctx.GetServerName);" \
  "WinSSL quickstart must stop using deprecated context-level SNI inspection"
require_absent "$quickstart" "当前版本无法支持，待实现" \
  "WinSSL quickstart must stop claiming client certificate requirements are unsupported"

echo "[PASS] WinSSL quickstart runtime truth contract passed"
