#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

roadmap="docs/ROADMAP.md"
readme="README.md"
api_ref="docs/reference/API_REFERENCE.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    echo "  file: $file"
    echo "  expected: $needle"
    exit 1
  fi
}

reject_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    rg -F -n -- "$needle" "$file" || true
    exit 1
  fi
}

require_fixed '`TSSLConfig` scope surgery 已经完成四条实现 slice：' "$roadmap" \
  "ROADMAP must account for all completed Stage 2 implementation slices"
require_fixed '`TSSLFactory.CreateContext(const TSSLContextConfig)` 已经直接应用 context-safe fields' "$roadmap" \
  "ROADMAP must record the completed TSSLContextConfig direct factory path"
require_fixed 'builder ordinary certificate/key/trust material 已经通过 `TSSLContextConfig` 投影' "$roadmap" \
  "ROADMAP must record the completed builder material projection slice"
require_fixed '下一条 Stage 2 切片继续收 active docs/examples 与 high-level guidance' "$roadmap" \
  "ROADMAP must route the next Stage 2 work to public guidance cleanup, not a completed slice"
reject_fixed '`TSSLConfig` scope surgery 已经完成前两条实现 slice：' "$roadmap" \
  "ROADMAP must not undercount completed TSSLConfig scope-surgery slices"
reject_fixed '下一条代码-heavy slice 是 `TSSLContextConfig` factory direct application' "$roadmap" \
  "ROADMAP must not point the next implementation slice at already-completed factory direct application"

require_fixed '用 context-safe config/factory 时，可选这两个字段：' "$readme" \
  "README must teach TSSLContextConfig as the recommended factory config path"
require_fixed '`TSSLContextConfig.ServerEarlyDataReplayStoreFile`' "$readme" \
  "README must list the replay-store file opt-in on TSSLContextConfig"
require_fixed '`TSSLContextConfig.ServerEarlyDataReplayStoreDirectory`' "$readme" \
  "README must list the replay-store directory opt-in on TSSLContextConfig"
require_fixed 'Legacy `TSSLConfig` 字段仍保留给 `v1.x` 兼容调用方' "$readme" \
  "README must keep legacy TSSLConfig compatibility explicit without teaching it as the new path"
require_fixed 'Context-safe factory 示例：' "$readme" \
  "README must rename the factory example to the context-safe path"
require_fixed 'LConfig: TSSLContextConfig;' "$readme" \
  "README factory replay-store example must use TSSLContextConfig"
require_fixed 'LConfig := CreateDefaultContextConfig(sslCtxServer);' "$readme" \
  "README factory replay-store example must start from CreateDefaultContextConfig"
reject_fixed 'Config/factory 示例：' "$readme" \
  "README must not keep the old legacy Config/factory example label"
reject_fixed '用 config/factory 时，可选这两个字段：' "$readme" \
  "README must not teach the mixed-scope config/factory wording as the primary path"

require_fixed '### Use `TSSLContextConfig` with `TSSLFactory.CreateContext(...)`' "$api_ref" \
  "API reference must document the context-safe factory replay-store path"
require_fixed '`TSSLContextConfig` 目前提供两个 server-only replay-store 字段：' "$api_ref" \
  "API reference must list replay-store opt-ins on TSSLContextConfig"
require_fixed 'LConfig: TSSLContextConfig;' "$api_ref" \
  "API reference replay-store factory example must use TSSLContextConfig"
require_fixed 'LConfig := CreateDefaultContextConfig(sslCtxServer);' "$api_ref" \
  "API reference replay-store factory example must start from CreateDefaultContextConfig"
require_fixed '### Legacy `TSSLConfig` compatibility path' "$api_ref" \
  "API reference must keep legacy TSSLConfig as an explicit compatibility path"
reject_fixed '### Use `TSSLConfig` with `TSSLFactory.CreateContext(...)`' "$api_ref" \
  "API reference must not present legacy TSSLConfig as the recommended replay-store factory path"

echo "[PASS] Stage 2 public guidance points at context-safe config and current roadmap truth"
