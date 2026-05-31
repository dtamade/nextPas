#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

example_file="examples/example_factory_usage.pas"
arch_doc="docs/reference/ARCHITECTURE.md"
example_test="tests/examples/test_lib_core_functionality.pas"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_absent() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_absent "Config.BufferSize :=" \
  "$example_file" \
  "example_factory_usage should not keep teaching BufferSize as a factory/context config field"
require_absent "Config.HandshakeTimeout :=" \
  "$example_file" \
  "example_factory_usage should not keep teaching HandshakeTimeout as a factory/context config field"
require_fixed "握手超时: 通过 TSSLConnector.WithTimeout / ISSLConnectionControl.SetTimeout 配置" \
  "$example_file" \
  "example_factory_usage no longer redirects handshake timeout to the current connection-control owner API"
require_fixed "缓冲策略: 通过外围 socket / stream / transport 配置" \
  "$example_file" \
  "example_factory_usage no longer redirects buffering to transport-level configuration"

require_absent "DefaultLibraryType: TSSLLibraryType;" \
  "$arch_doc" \
  "reference/ARCHITECTURE still documents the stale TSSLConfig pseudo-record"
require_fixed '`TSSLConfig` 并不是“所有字段都在同一层直接生效”的纯层级配置。' \
  "$arch_doc" \
  "reference/ARCHITECTURE no longer states the mixed-scope truth for TSSLConfig"
require_fixed "**library-scoped defaults**" \
  "$arch_doc" \
  "reference/ARCHITECTURE no longer lists library-scoped defaults"
require_fixed "**context-scoped**" \
  "$arch_doc" \
  "reference/ARCHITECTURE no longer lists context-scoped TSSLConfig fields"
require_fixed "**connection-scoped**" \
  "$arch_doc" \
  "reference/ARCHITECTURE no longer lists connection-scoped TSSLConfig fields"
require_fixed '`TSSLConnector.WithTimeout` / `ISSLConnectionControl.SetTimeout`' \
  "$arch_doc" \
  "reference/ARCHITECTURE no longer points connection-scoped timeout fields at the current owner path"
require_fixed "**compatibility-only**" \
  "$arch_doc" \
  "reference/ARCHITECTURE no longer lists compatibility-only TSSLConfig fields"

require_fixed "INTENTIONAL_API_SURFACE: context-level SNI setter coverage." \
  "$example_test" \
  "test_lib_core_functionality lost the API-surface label for direct context SetServerName coverage"

echo "[PASS] TSSLConfig active guidance stays aligned across example usage and architecture reference"
