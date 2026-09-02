#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/.tmp/compiler-query-default-options"
STAGE0_SOURCE="$REPO_ROOT/tools/stage0/nextpas.pas"
STAGE0_BINARY="$BUILD_DIR/nextpas"
BUILD_LOG="$BUILD_DIR/fpc.log"
QUERY_OUTPUT="$BUILD_DIR/query.out"
FIXTURE_RELATIVE_PATH="compiler/tests/fixtures/query_default_options/query_default_options.pas"
FIXTURE_DIR="$REPO_ROOT/compiler/tests/fixtures/query_default_options"
CACHE_ROOT="$FIXTURE_DIR/.nextpas"

rm -rf "$BUILD_DIR" "$CACHE_ROOT"
mkdir -p "$BUILD_DIR"
trap 'rm -rf "$CACHE_ROOT"' EXIT

# -gt makes omitted local-option initialization deterministic instead of
# depending on whatever bytes happen to be on the stack.
if ! fpc -B -gt \
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
  -Fu"$REPO_ROOT/tools/stage0" \
  -Fu"$REPO_ROOT/rtl/core/base" \
  -Fu"$REPO_ROOT/rtl/core/text" \
  -Fu"$REPO_ROOT/core/src" \
  -Fi"$REPO_ROOT/core/src" \
  -FE"$BUILD_DIR" \
  -FU"$BUILD_DIR" \
  "$STAGE0_SOURCE" >"$BUILD_LOG" 2>&1; then
  cat "$BUILD_LOG" >&2
  exit 1
fi

if ! (cd "$REPO_ROOT" && \
  NEXTPAS_REPO_ROOT="$REPO_ROOT" \
  "$STAGE0_BINARY" query symbols "$FIXTURE_RELATIVE_PATH" \
    --target linux-x86_64 --workspace "$REPO_ROOT" \
    >"$QUERY_OUTPUT" 2>&1); then
  cat "$QUERY_OUTPUT" >&2
  exit 1
fi

if [[ -e "$CACHE_ROOT" ]]; then
  find "$CACHE_ROOT" -maxdepth 2 -print >&2
  printf '[FAIL] query created incremental cache without --incremental\n' >&2
  exit 1
fi

grep -Fqx 'status=success' "$QUERY_OUTPUT" || {
  cat "$QUERY_OUTPUT" >&2
  printf '[FAIL] query did not report success\n' >&2
  exit 1
}

printf 'query-default-options=pass incremental=false\n'
