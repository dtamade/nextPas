#!/usr/bin/env bash
set -euo pipefail

api_ref="docs/reference/API_REFERENCE.md"
arch_ref="docs/reference/ARCHITECTURE.md"
shared_helper="src/nextpas.core.tls.context.config.pas"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"
  if ! grep -Fq "$needle" "$file"; then
    echo "[FAIL] $message"
    echo "  missing: $needle"
    echo "  file: $file"
    exit 1
  fi
}

require_fixed 'factory request path 和 direct-library context path 都不接受它们的自定义值；请改走 `TSSLConnector.WithTimeout` / `TSSLAcceptor.WithTimeout`，连接创建后若需要 runtime override 则优先走 `ISSLConnectionControl.SetTimeout(...)`，其余 buffer 策略继续放在外围 transport / IO 配置。' \
  "$api_ref" \
  "API reference no longer states that direct-library context path rejects connection-scoped timeout/buffer defaults"

require_fixed '这两个字段不属于 context/factory/direct-library config 主路径，应改走 `TSSLConnector.WithTimeout` / `ISSLConnectionControl.SetTimeout` 或外围 IO/transport 配置。' \
  "$arch_ref" \
  "Architecture reference no longer states that direct-library context path rejects connection-scoped timeout/buffer defaults"

require_fixed 'procedure ValidateDirectLibraryConnectionScope(const AConfig: TSSLConfig;' \
  "$shared_helper" \
  "shared direct-library connection-scope validator is missing"
require_fixed 'HandshakeTimeout is connection-scoped. Use TSSLConnector.WithTimeout, ' \
  "$shared_helper" \
  "shared direct-library validator no longer mentions HandshakeTimeout replacement path"
require_fixed 'ISSLConnectionControl.SetTimeout instead of ' \
  "$shared_helper" \
  "shared direct-library validator no longer points to the current timeout runtime owner"
require_fixed 'BufferSize is not a context-scoped direct-library option. Configure buffering in the surrounding ' \
  "$shared_helper" \
  "shared direct-library validator no longer mentions BufferSize replacement path"

check_backend() {
  local file="$1"
  if ! rg -n --quiet 'ValidateDirectLibraryConnectionScope\(' "$file"; then
    echo "[FAIL] $file does not call the shared direct-library connection-scope validator"
    exit 1
  fi
}

check_backend "src/nextpas.core.tls.openssl.backed.pas"
check_backend "src/nextpas.core.tls.freepascal.lib.pas"
check_backend "src/nextpas.core.tls.winssl.lib.pas"
check_backend "src/nextpas.core.tls.mbedtls.lib.pas"
check_backend "src/nextpas.core.tls.wolfssl.lib.pas"

echo "[PASS] direct-library connection-scope clarification remains aligned across backend library paths"
