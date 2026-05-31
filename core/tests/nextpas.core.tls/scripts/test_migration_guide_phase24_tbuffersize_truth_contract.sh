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

guide="docs/guides/MIGRATION_GUIDE_PHASE_2.4.md"

printf '[TEST] migration guide phase 2.4 TBufferSize truth contract\n'

require_fixed "$guide" '当前 `fafafa.ssl` 的 TLS context / factory / direct-library 路径并没有单独的 `WithBufferSize(...)` / `SetBuffer(...)` public 入口。' \
  "phase 2.4 migration guide must state that current TLS paths do not expose a buffer-size public entrypoint"
require_fixed "$guide" '当前 `TSSLConfig.BufferSize` 仍是 connection-scoped buffering hint；若在 factory / direct-library 创建路径写入自定义值，会被显式拒绝。' \
  "phase 2.4 migration guide must state the current TSSLConfig.BufferSize reject truth"
require_fixed "$guide" '若你在当前库里需要调整缓冲策略，应放在外围 socket / stream / transport / app-level buffering layer。' \
  "phase 2.4 migration guide must redirect buffer sizing to transport-level policy"
require_fixed "$guide" '下面这个组合示意应理解为“你自己的 typed wrapper / policy boundary”，不是当前 `fafafa.ssl` 直接提供的单一 SSL 配置入口。' \
  "phase 2.4 migration guide must label the combined typed example as wrapper-level guidance"
require_absent "$guide" 'SetBuffer(ABufferSize.ToBytes);' \
  "phase 2.4 migration guide must stop teaching a fake SetBuffer TLS entrypoint"
require_absent "$guide" 'procedure ConfigureSSLConnection(' \
  "phase 2.4 migration guide must stop presenting the combined example as a current direct SSL entrypoint"

printf '[PASS] migration guide phase 2.4 TBufferSize truth contract passed\n'
