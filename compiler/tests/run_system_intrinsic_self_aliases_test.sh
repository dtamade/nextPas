#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_ROOT="$REPO_ROOT/build/.tmp"
SOURCE_PATH="$SCRIPT_DIR/test_system_intrinsic_self_aliases.pas"
mkdir -p "$BUILD_ROOT"
BUILD_DIR="$(mktemp -d "$BUILD_ROOT/compiler-system-intrinsic-self-aliases.XXXXXX")"
BINARY_PATH="$BUILD_DIR/test_system_intrinsic_self_aliases"
BUILD_LOG="$BUILD_DIR/fpc.log"
RUN_LOG="$BUILD_DIR/run.log"
SYSTEM_SOURCE="$REPO_ROOT/units/linux-x86_64/System.pas"
SYSTEM_FIXTURE="$BUILD_DIR/System.pas"

trap 'rm -rf "$BUILD_DIR"' EXIT

if ! fpc -B \
  -Fu"$REPO_ROOT/compiler/syntax" \
  -Fu"$REPO_ROOT/compiler/diagnostics" \
  -Fu"$REPO_ROOT/compiler/src" \
  -Fu"$REPO_ROOT/compiler/frontend" \
  -Fu"$REPO_ROOT/compiler/sema" \
  -Fu"$REPO_ROOT/compiler/lower" \
  -Fu"$REPO_ROOT/compiler/ir" \
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

printf 'system-intrinsic-self-aliases-build=pass\n'

cp "$SYSTEM_SOURCE" "$SYSTEM_FIXTURE"
printf '\n{ self-alias regression fixture %s }\n' "$$" >>"$SYSTEM_FIXTURE"

set +e
(cd "$BUILD_DIR" && timeout --kill-after=1s 5s \
  "$BINARY_PATH" "$SYSTEM_FIXTURE") \
  >"$RUN_LOG" 2>&1
RUN_EXIT=$?
set -e

if [[ "$RUN_EXIT" -ne 0 ]]; then
  cat "$RUN_LOG" >&2
  if [[ "$RUN_EXIT" -eq 124 ]]; then
    printf 'system-intrinsic-self-aliases-timeout=fail\n' >&2
  fi
  exit "$RUN_EXIT"
fi

cat "$RUN_LOG"
