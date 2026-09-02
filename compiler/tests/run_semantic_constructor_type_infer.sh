#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/.tmp/compiler-semantic-constructor-type-infer"
SOURCE_PATH="$SCRIPT_DIR/test_semantic_constructor_type_infer.pas"
BINARY_PATH="$BUILD_DIR/test_semantic_constructor_type_infer"
BUILD_LOG="$BUILD_DIR/fpc.log"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if ! fpc -B \
  -Fu"$REPO_ROOT/compiler/src" \
  -Fu"$REPO_ROOT/compiler/frontend" \
  -Fu"$REPO_ROOT/compiler/diagnostics" \
  -Fu"$REPO_ROOT/compiler/targets" \
  -Fu"$REPO_ROOT/compiler/syntax" \
  -Fu"$REPO_ROOT/compiler/sema" \
  -Fu"$REPO_ROOT/compiler/lower" \
  -Fu"$REPO_ROOT/compiler/ir" \
  -Fu"$REPO_ROOT/compiler/backend" \
  -Fu"$REPO_ROOT/compiler/toolchain" \
  -Fu"$REPO_ROOT/rtl/core/base" \
  -Fu"$REPO_ROOT/rtl/core/text" \
  -Fu"$REPO_ROOT/core/src" \
  -Fi"$REPO_ROOT/core/src" \
  -FE"$BUILD_DIR" \
  -FU"$BUILD_DIR" \
  "$SOURCE_PATH" >"$BUILD_LOG" 2>&1; then
  cat "$BUILD_LOG" >&2
  exit 1
fi

printf 'semantic-constructor-type-infer-build=pass\n'
"$BINARY_PATH"
