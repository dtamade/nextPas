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

quick30="docs/guides/QUICKSTART_30SEC.md"
quick5="docs/guides/5_MINUTE_QUICKSTART.md"

echo "[TEST] high-entry quickstarts captured-output truth contract"

require_fixed "$quick30" "这些命令是当前可执行 quickstart 入口，但不要把固定输出文本、OpenSSL 版本字符串或某次 TLS 协商结果当成长期文档 truth。" \
  "QUICKSTART_30SEC must demote captured runtime output snapshots"
require_fixed "$quick5" "这些命令是当前可执行 quickstart 入口，但不要把固定 OpenSSL 版本、TLS 版本、密码套件或 HTTP 响应预览文本当成长期文档 truth。" \
  "5_MINUTE_QUICKSTART must demote captured runtime output snapshots"
require_fixed "$quick5" "git clone https://github.com/dtamade/nextpas.core.tls.git" \
  "5_MINUTE_QUICKSTART must use the current public clone URL"

require_absent "$quick30" "预期输出：" \
  "QUICKSTART_30SEC must stop embedding captured expected-output blocks"
require_absent "$quick30" "Version: OpenSSL 3.x.x ..." \
  "QUICKSTART_30SEC must stop embedding captured OpenSSL version snapshots"
require_absent "$quick30" "协议: TLS 1.3" \
  "QUICKSTART_30SEC must stop embedding captured TLS-version snapshots"
require_absent "$quick30" "密码套件: TLS_AES_256_GCM_SHA384" \
  "QUICKSTART_30SEC must stop embedding captured cipher snapshots"

require_absent "$quick5" "**预期输出**:" \
  "5_MINUTE_QUICKSTART must stop embedding captured expected-output blocks"
require_absent "$quick5" "Version: OpenSSL 3.0.2 15 Mar 2022" \
  "5_MINUTE_QUICKSTART must stop embedding captured OpenSSL version snapshots"
require_absent "$quick5" "Backend: OpenSSL / OpenSSL 3.0.2 15 Mar 2022" \
  "5_MINUTE_QUICKSTART must stop embedding captured backend/version snapshots"
require_absent "$quick5" "TLS 版本: TLS 1.3" \
  "5_MINUTE_QUICKSTART must stop embedding captured TLS-version snapshots"
require_absent "$quick5" "密码套件: TLS_AES_256_GCM_SHA384" \
  "5_MINUTE_QUICKSTART must stop embedding captured cipher snapshots"
require_absent "$quick5" "HTTP/1.1 200 OK" \
  "5_MINUTE_QUICKSTART must stop embedding captured HTTP response snapshots"
require_absent "$quick5" "git clone https://github.com/your-org/nextpas.core.tls.git" \
  "5_MINUTE_QUICKSTART must stop using placeholder clone URL"

echo "[PASS] high-entry quickstarts captured-output truth contract passed"
