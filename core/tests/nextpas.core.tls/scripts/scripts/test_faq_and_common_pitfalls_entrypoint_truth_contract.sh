#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] excerpt from $file:"
    sed -n '1,260p' "$file" || true
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if rg -n -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    rg -n -F -- "$pattern" "$file" || true
    exit 1
  fi
}

FAQ="docs/guides/FAQ.md"
PITFALLS="docs/guides/COMMON_PITFALLS.md"

assert_not_contains "$FAQ" \
  "唯一要求：系统安装OpenSSL 1.1.1+或3.x。" \
  "FAQ still publishes OpenSSL as a universal runtime requirement"
assert_not_contains "$FAQ" \
  "TSSLLibrary.Instance" \
  "FAQ still teaches the removed singleton loader path"
assert_not_contains "$PITFALLS" \
  "TSSLLibrary.Instance.SetCustomLibraryPath" \
  "COMMON_PITFALLS still teaches the removed singleton custom-path API"

assert_contains "$FAQ" \
  '普通新代码推荐直接 `uses fafafa.ssl, nextpas.core.tls.context.builder;`，然后通过 `TSSLContextBuilder` / `TSSLConnector` 建立 TLS；只有在你明确固定某个 backend 时，才需要关心 backend-specific 依赖。' \
  "FAQ should teach the current preferred entrypoint"
assert_contains "$FAQ" \
  'Windows 可以直接使用 `WinSSL` backend，不要求安装 OpenSSL。' \
  "FAQ should record WinSSL as a no-OpenSSL Windows path"
assert_contains "$FAQ" \
  'FreePascal backend 是纯 Pascal 路径，不要求系统 OpenSSL。' \
  "FAQ should record the FreePascal backend dependency truth"
assert_contains "$FAQ" \
  'Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);' \
  "FAQ should show the current explicit OpenSSL backend factory path"
assert_contains "$FAQ" \
  "SetCustomLibraryPaths('/custom/path/libcrypto.so', '/custom/path/libssl.so');" \
  "FAQ should document the current OpenSSL-specific custom-path fallback"
assert_contains "$FAQ" \
  "https://github.com/dtamade/fafafa.ssl/issues" \
  "FAQ should link to the live repository issues URL"
assert_contains "$FAQ" \
  '[QUICKSTART.md](QUICKSTART.md)' \
  "FAQ should link to the live quickstart doc"
assert_contains "$FAQ" \
  '[API_REFERENCE.md](../reference/API_REFERENCE.md)' \
  "FAQ should link to the live API reference doc"
assert_contains "$FAQ" \
  "本FAQ基于fafafa.ssl v1.5.0。" \
  "FAQ should reflect the current shipped version line"
assert_not_contains "$FAQ" \
  "yourusername" \
  "FAQ should not keep placeholder GitHub owner strings"

assert_contains "$PITFALLS" \
  "SetCustomLibraryPaths('/opt/homebrew/opt/openssl@3/lib/libcrypto.dylib', '/opt/homebrew/opt/openssl@3/lib/libssl.dylib');" \
  "COMMON_PITFALLS should use the current OpenSSL-specific custom-path API"
assert_contains "$PITFALLS" \
  '不要把 OpenSSL-specific override 当成所有平台的通用初始化步骤。' \
  "COMMON_PITFALLS should scope the custom-path override as backend-specific"

echo "[PASS] FAQ and COMMON_PITFALLS entrypoint/backend truth contract passed"
