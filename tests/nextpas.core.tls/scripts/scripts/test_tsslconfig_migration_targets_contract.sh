#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_ref="docs/reference/API_REFERENCE.md"
roadmap="docs/plans/2026-05-18-tsslconfig-public-surface-slimming-roadmap.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '## TSSLConfig Migration Targets' \
  "$api_ref" \
  "API reference no longer contains the TSSLConfig migration-targets section"
require_fixed '当前 additive surface：`TSSLContextConfig` + `CreateDefaultContextConfig(...)` / `TSSLFactory.CreateContext(const TSSLContextConfig)`' \
  "$api_ref" \
  "API reference no longer maps context-safe config fields to TSSLContextConfig"
require_fixed '当前推荐入口：`TSSLLibraryDefaults` + `GetLibraryDefaults(...)` / `ApplyLibraryDefaults(...)`' \
  "$api_ref" \
  "API reference no longer maps LogLevel to library default config APIs"
require_fixed 'runtime owner 仍是 `ISSLLibrary.SetLogCallback(...)`' \
  "$api_ref" \
  "API reference no longer records the runtime owner for LogCallback"
require_fixed '当前推荐入口：`TSSLConnector.WithTimeout(...)` / `TSSLAcceptor.WithTimeout(...)`' \
  "$api_ref" \
  "API reference no longer maps HandshakeTimeout to connection timeout APIs"
require_fixed '优先通过 `ISSLConnectionControl.SetTimeout(...)`' \
  "$api_ref" \
  "API reference no longer records ISSLConnectionControl as the runtime timeout override owner"
require_fixed '当前推荐入口：外围 socket / stream / transport / app-level buffer policy' \
  "$api_ref" \
  "API reference no longer maps BufferSize to transport-level configuration"
require_fixed '当前推荐入口：`TSSLConnectionBuilder.WithHostname(...)` / `ISSLClientConnection.SetServerName(...)` / `TSSLConnector.Connect*(..., ServerName)`' \
  "$api_ref" \
  "API reference no longer maps ServerName to per-connection SNI surfaces"
require_fixed '当前推荐入口：直接写 `Options`，或 builder 的 `WithOption(...)` / option snapshot path' \
  "$api_ref" \
  "API reference no longer maps option-bridge booleans back to Options / WithOption"
require_fixed '`v2` 方向：不再把 library defaults 混在 context/request config record 中。' \
  "$api_ref" \
  "API reference no longer states the v2 direction for library-scoped defaults"
require_fixed '`v2` 方向：从 context factory record 中移出这类 connection-adjacent 字段。' \
  "$api_ref" \
  "API reference no longer states the v2 direction for connection-scoped fields"
require_fixed '`v2` 方向：不再作为 context-level config field 继续主挂载。' \
  "$api_ref" \
  "API reference no longer states the v2 direction for ServerName"
require_fixed '`v2` 方向：不再把这组三个 legacy booleans 当成正常首选写入口。' \
  "$api_ref" \
  "API reference no longer states the v2 direction for option-bridge booleans"

require_fixed '# TSSLConfig Public-Surface Slimming Roadmap' \
  "$roadmap" \
  "slimming roadmap doc is missing"
require_fixed '## Field-Level Migration Decisions' \
  "$roadmap" \
  "slimming roadmap no longer captures field-level migration decisions"
require_fixed '### 迁移到 library defaults surface' \
  "$roadmap" \
  "slimming roadmap no longer keeps the library-defaults migration bucket"
require_fixed '### 迁移到 connection / transport surface' \
  "$roadmap" \
  "slimming roadmap no longer keeps the connection/transport migration bucket"
require_fixed '### 迁移到 per-connection SNI surface' \
  "$roadmap" \
  "slimming roadmap no longer keeps the per-connection SNI migration bucket"
require_fixed '### 迁移到 option-set surface' \
  "$roadmap" \
  "slimming roadmap no longer keeps the option-set migration bucket"

echo "[PASS] TSSLConfig migration targets stay aligned across API reference and slimming roadmap"
