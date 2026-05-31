#!/usr/bin/env bash
set -euo pipefail

DOCS=(
  "docs/zh/FAQ.md"
  "docs/zh/快速入门.md"
  "docs/zh/安装配置.md"
  "docs/zh/使用指南/客户端开发.md"
  "docs/zh/API参考/概述.md"
)

require_absent_all() {
  local pattern="$1"
  if rg -F -q "$pattern" "${DOCS[@]}"; then
    echo "[FAIL] unexpected pattern present: $pattern" >&2
    exit 1
  fi
}

require_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -F -q "$pattern" "$file"; then
    echo "[FAIL] missing pattern in $file: $pattern" >&2
    exit 1
  fi
}

require_absent_all 'TSSLFactory.CreateContext(sslOpenSSL, sslCtxClient)'
require_absent_all 'TSSLFactory.CreateContext(sslWinSSL, sslCtxClient)'
require_absent_all 'CreateConnection;'
require_absent_all 'Connect(AHost, APort)'
require_absent_all 'Connect(FHost, FPort)'
require_absent_all "Connect('example.com', 443)"
require_absent_all "Connect('www.google.com', 443)"
require_absent_all 'LoadSystemCertificates'

require_contains 'docs/zh/FAQ.md' 'TSSLContextBuilder'
require_contains 'docs/zh/FAQ.md' 'WithSystemRoots'
require_contains 'docs/zh/快速入门.md' 'TSSLConnector'
require_contains 'docs/zh/安装配置.md' 'TSSLFactory.GetLibraryInstance(sslOpenSSL)'
require_contains 'docs/zh/使用指南/客户端开发.md' 'ISSLClientConnection'
require_contains 'docs/zh/API参考/概述.md' 'TSSLConnector'

echo "[PASS] zh entry docs current public truth contract passed"
