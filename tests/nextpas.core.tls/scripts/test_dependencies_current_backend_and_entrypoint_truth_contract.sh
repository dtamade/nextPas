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
    sed -n '1,380p' "$file" || true
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

DOC="docs/DEPENDENCIES.md"

assert_not_contains "$DOC" \
  "Lib := CreateSSLLibrary(sslWinSSL);" \
  "DEPENDENCIES still teaches the removed WinSSL helper entrypoint"
assert_not_contains "$DOC" \
  "Lib := CreateSSLLibrary(sslOpenSSL);" \
  "DEPENDENCIES still teaches the removed OpenSSL helper entrypoint"
assert_not_contains "$DOC" \
  "Lib := CreateSSLLibrary; // Windows默认WinSSL" \
  "DEPENDENCIES still teaches the removed auto helper entrypoint"
assert_not_contains "$DOC" \
  "| **Windows 10 (20348+)** | ✅ | ✅ | 完全支持 |" \
  "DEPENDENCIES still publishes the stale Windows 10 20348+ TLS 1.3 threshold"

assert_contains "$DOC" \
  "| **Free Pascal** | ≥ 3.2.0 | Pascal编译器（推荐 3.2.2+） |" \
  "DEPENDENCIES should reflect the current shipped FPC baseline"
assert_contains "$DOC" \
  "#### 选项C：FreePascal后端" \
  "DEPENDENCIES should include the shipped FreePascal backend on Windows"
assert_contains "$DOC" \
  "#### 选项A：OpenSSL后端（最常见）" \
  "DEPENDENCIES should explicitly scope Linux/macOS OpenSSL guidance"
assert_contains "$DOC" \
  "#### 选项B：FreePascal后端（无外部 SSL 动态库）" \
  "DEPENDENCIES should include the zero-external-SSL FreePascal path on Unix-like platforms"
assert_contains "$DOC" \
  "Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);" \
  "DEPENDENCIES should use the current explicit WinSSL entrypoint"
assert_contains "$DOC" \
  "Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);" \
  "DEPENDENCIES should use the current explicit OpenSSL entrypoint"
assert_contains "$DOC" \
  "Lib := TSSLFactory.GetLibraryInstance(sslAutoDetect);  // 让工厂按当前可用性与优先级选择" \
  "DEPENDENCIES should use the current auto-detect entrypoint"
assert_contains "$DOC" \
  "| **Windows 10 (>= 18362)** | ✅ | ✅ | 完全支持 |" \
  "DEPENDENCIES should reflect the current WinSSL TLS 1.3 threshold"
assert_contains "$DOC" \
  '- 快速入门：`guides/GETTING_STARTED.md`' \
  "DEPENDENCIES should point to the live getting-started doc"
assert_contains "$DOC" \
  '- API 文档：`reference/API_REFERENCE.md`' \
  "DEPENDENCIES should point to the live API reference doc"
assert_contains "$DOC" \
  "**文档版本**: v1.5.0" \
  "DEPENDENCIES footer should reflect the current doc version"

echo "[PASS] DEPENDENCIES current backend and entrypoint truth contract passed"
