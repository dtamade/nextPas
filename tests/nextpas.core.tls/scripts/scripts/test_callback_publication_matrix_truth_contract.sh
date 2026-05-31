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
  local text="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$text" "$file"; then
    fail "$message"
  fi
}

backend_matrix_file="docs/BACKEND_CAPABILITY_MATRIX.md"
winssl_matrix_file="docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"

echo "[TEST] callback publication matrix truth contract"

require_fixed "$backend_matrix_file" "| **Context Callbacks**        | ⚠️         | ✅      | ⚠️     | ❌      | ❌      |" \
  "backend capability quick-reference matrix must publish current callback availability"
require_fixed "$backend_matrix_file" '`Context Callbacks` 这一行按当前 published runtime truth 汇总：' \
  "backend capability matrix must explain the callback row semantics"
require_fixed "$backend_matrix_file" '- `OpenSSL`: verify/password/info callback 都已发布并具备 runtime wiring' \
  "backend capability matrix must record OpenSSL callback publication truth"
require_fixed "$backend_matrix_file" '- `WinSSL`: 仅 verify/info callback 已发布；password callback 当前仍为 unsupported' \
  "backend capability matrix must record current WinSSL partial callback publication truth"
require_fixed "$backend_matrix_file" '- `FreePascal`: 仅 verify callback 已发布并接入 peer-certificate trust failure path；password/info callback 当前仍为 unsupported' \
  "backend capability matrix must record current FreePascal partial callback publication truth"
require_fixed "$backend_matrix_file" '- `WolfSSL` / `MbedTLS`: `SupportsCallbacks=False`，verify/password/info setter 当前都已 fail-closed' \
  "backend capability matrix must record unpublished callback backend fail-closed truth"

require_fixed "$winssl_matrix_file" "| Context callbacks               | ⚠️ 部分                   | 当前仅 verify/info runtime path 已发布；password callback 仍为 unsupported" \
  "WinSSL backend matrix must record callback publication granularity"
require_fixed "$winssl_matrix_file" '> `SupportsCallbacks=True` 在 WinSSL 上当前是 coarse-grained publication flag：' \
  "WinSSL backend matrix must explain the coarse-grained callback flag"
require_fixed "$winssl_matrix_file" "> verify/info callback 已发布，password callback 仍未接入 runtime，non-nil assignment 会 fail-closed 为 unsupported。" \
  "WinSSL backend matrix must explain password callback unsupported truth"

echo "[PASS] callback publication matrix truth contract passed"
