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

guide="docs/guides/LINUX_QUICKSTART.md"
probe="tests/contract/test_linux_quickstart_public_entry_probe.pas"

echo "[TEST] linux quickstart current public truth contract"

require_fixed "$guide" "  fafafa.ssl;" \
  "LINUX_QUICKSTART sample must use the public facade unit"
require_fixed "$guide" "  Lib := TSSLFactory.GetLibraryInstance(sslAutoDetect);" \
  "LINUX_QUICKSTART sample must use current public library entrypoint"
require_fixed "$guide" "  WriteLn('检测到: ', LibraryTypeToString(Lib.GetLibraryType));" \
  "LINUX_QUICKSTART sample must use current public backend-name helper"
require_fixed "$guide" "examples/01_tls_client.pas" \
  "LINUX_QUICKSTART must point to the current TLS client example"
require_fixed "$guide" "### Q: 编译时报 \"Can't find unit fafafa.ssl\"" \
  "LINUX_QUICKSTART FAQ must route new users to the public facade unit"
require_fixed "$guide" "nextpas.core.tls.pas                # 主门面 / 当前普通入口" \
  "LINUX_QUICKSTART project structure must show the current public facade"
require_fixed "$guide" "nextpas.core.tls.context.builder.pas # 推荐 context builder 入口" \
  "LINUX_QUICKSTART project structure must show the current builder entrypoint"
require_fixed "$guide" "nextpas.core.tls.openssl.backed.pas # OpenSSL ISSLLibrary 实现" \
  "LINUX_QUICKSTART project structure must stop naming a nonexistent OpenSSL facade unit"
require_fixed "$guide" "**更新日期**: 2026-05-21" \
  "LINUX_QUICKSTART metadata must be current"
require_fixed "$guide" "**适用版本**: fafafa.ssl v1.5.0" \
  "LINUX_QUICKSTART version metadata must match current release truth"
require_fixed "$guide" "https://github.com/dtamade/fafafa.ssl/issues" \
  "LINUX_QUICKSTART GitHub URL must point to the real repository"

require_absent "$guide" "  nextpas.core.tls.factory;" \
  "LINUX_QUICKSTART must stop teaching direct factory-only imports in the entry example"
require_absent "$guide" "DetectBestLibrary;" \
  "LINUX_QUICKSTART must stop teaching the stale bare DetectBestLibrary helper"
require_absent "$guide" "GetLibraryTypeName(" \
  "LINUX_QUICKSTART must stop teaching the stale GetLibraryTypeName helper"
require_absent "$guide" "GetLibraryInstance(LibType);" \
  "LINUX_QUICKSTART must stop teaching the stale bare GetLibraryInstance call"
require_absent "$guide" "examples/01_basic_ssl_client.pas" \
  "LINUX_QUICKSTART must stop pointing to the removed basic SSL client example"
require_absent "$guide" "nextpas.core.tls.openssl.pas" \
  "LINUX_QUICKSTART must stop naming the nonexistent nextpas.core.tls.openssl.pas unit"
require_absent "$guide" "**适用版本**: fafafa.ssl v1.0.0-rc" \
  "LINUX_QUICKSTART must stop advertising the stale v1.0.0-rc snapshot"
require_absent "$guide" "yourusername/fafafa.ssl" \
  "LINUX_QUICKSTART must stop using placeholder GitHub repository URLs"

mkdir -p tmp/linux_quickstart_public_entry_probe
fpc -B -Fu./src \
  -FUtmp/linux_quickstart_public_entry_probe \
  -FEtmp/linux_quickstart_public_entry_probe \
  -otmp/linux_quickstart_public_entry_probe/test_linux_quickstart_public_entry_probe \
  "$probe" >/dev/null

echo "[PASS] linux quickstart current public truth contract passed"
