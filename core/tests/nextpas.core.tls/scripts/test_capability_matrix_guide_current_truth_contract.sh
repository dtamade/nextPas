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

DOC="docs/CAPABILITY_MATRIX_GUIDE.md"

assert_not_contains "$DOC" \
  "**版本**: v1.2.0" \
  "CAPABILITY_MATRIX_GUIDE still publishes the old v1.2.0 doc version"
assert_not_contains "$DOC" \
  "https://github.com/your-org/fafafa.ssl/issues" \
  "CAPABILITY_MATRIX_GUIDE still keeps the placeholder support URL"
assert_not_contains "$DOC" \
  "Backends: array[0..3] of TSSLLibraryType =" \
  "CAPABILITY_MATRIX_GUIDE still hardcodes a backend list that can miss shipped backends"

assert_contains "$DOC" \
  "**版本**: v1.5.0" \
  "CAPABILITY_MATRIX_GUIDE should reflect the current shipped version"
assert_contains "$DOC" \
  "能力矩阵最早在 fafafa.ssl v1.2.0 引入；本文当前内容对齐 fafafa.ssl v1.5.0 shipped truth。" \
  "CAPABILITY_MATRIX_GUIDE should distinguish historical introduction from current truth"
assert_contains "$DOC" \
  "uses fafafa.ssl;" \
  "CAPABILITY_MATRIX_GUIDE quickstart should use the current facade import"
assert_contains "$DOC" \
  "WriteLn('Backend: ', LibraryTypeToString(Caps.BackendType));" \
  "CAPABILITY_MATRIX_GUIDE should use the public LibraryTypeToString helper in capability snippets"
assert_contains "$DOC" \
  "WriteLn('Optimal Configuration for ', LibraryTypeToString(ABackend));" \
  "CAPABILITY_MATRIX_GUIDE should use the public LibraryTypeToString helper in config examples"
assert_contains "$DOC" \
  '普通 capability / native-handle 查询不必再拆分回 `uses nextpas.core.tls.base` / `nextpas.core.tls.factory`；`fafafa.ssl` 已 re-export 当前所需的 capability helper surface。' \
  "CAPABILITY_MATRIX_GUIDE should document the current public import guidance"
assert_contains "$DOC" \
  "Result := TSSLFactory.DetectBestLibrary;" \
  "CAPABILITY_MATRIX_GUIDE should use the current factory fallback truth"
assert_contains "$DOC" \
  "AvailableBackends := TSSLFactory.GetAvailableLibraries;" \
  "CAPABILITY_MATRIX_GUIDE examples should enumerate currently available backends dynamically"
assert_contains "$DOC" \
  "sslFreePascal" \
  "CAPABILITY_MATRIX_GUIDE should mention the shipped FreePascal backend"
assert_contains "$DOC" \
  "- **FreePascal**: 64% (Pascal-first / pure TLS core path)" \
  "CAPABILITY_MATRIX_GUIDE compatibility FAQ should include the current FreePascal value"
assert_contains "$DOC" \
  "https://github.com/dtamade/fafafa.ssl/issues" \
  "CAPABILITY_MATRIX_GUIDE should link to the live repository issues URL"
assert_contains "$DOC" \
  "**文档版本**: v1.5.0" \
  "CAPABILITY_MATRIX_GUIDE footer should reflect the current doc version"
assert_not_contains "$DOC" \
  "SSL_LIBRARY_NAMES[" \
  "CAPABILITY_MATRIX_GUIDE façade-only examples must stop teaching base-only SSL_LIBRARY_NAMES constants"

echo "[PASS] CAPABILITY_MATRIX_GUIDE current truth contract passed"
