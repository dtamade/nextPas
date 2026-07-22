#!/usr/bin/env bash
# Batch 25: record string field + const record string sret + mini Fail.
# Not M2-A. claim-level set at end.
# Adapted for main stage0 CLI: --out-dir (not tip --artifact-root).
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

STAGE0="${STAGE0:-$ROOT/build/stage0-bootstrap/nextpas}"
if [ ! -x "$STAGE0" ]; then
  echo "FAIL: missing stage0 nextpas at $STAGE0 (make rebuild-compiler)" >&2
  exit 2
fi

# Freestanding llvm link pulls build/runtime/<target>/libnprt.a (FindRuntimeLibrary).
if [ ! -f "$ROOT/build/runtime/linux-x86_64/libnprt.a" ]; then
  echo "[rec-str-abi] building libnprt.a..."
  make -C "$ROOT/rtl/runtime" all
fi
if [ ! -f "$ROOT/build/runtime/linux-x86_64/libnprt.a" ]; then
  echo "FAIL: missing libnprt.a after make -C rtl/runtime" >&2
  exit 2
fi

RUN="${RUN_DIR:-$ROOT/build/rec-str-abi-focused-$$}"
mkdir -p "$RUN"
trap 'rm -rf "$RUN"' EXIT

resolve_exe() {
  local name="$1" art="$2" build_log="$3"
  local exe=""
  exe="$(grep -m1 '^artifact=' "$build_log" 2>/dev/null | cut -d= -f2- || true)"
  if [ -n "$exe" ] && [ -x "$exe" ]; then
    printf '%s\n' "$exe"
    return 0
  fi
  exe="$(find "$art" -type f -executable -name "$name" 2>/dev/null | head -1 || true)"
  if [ -n "$exe" ]; then
    printf '%s\n' "$exe"
    return 0
  fi
  return 1
}

build_and_run() {
  local name="$1" src="$2" expect="$3"
  local art="$RUN/$name"
  mkdir -p "$art"
  echo "[rec-str-abi] build $name..."
  if ! "$STAGE0" build "$src" \
    --target linux-x86_64 \
    --toolchain-binding linux-x86_64-to-linux-x86_64-llvm \
    --workspace "$ROOT" \
    --out-dir "$art" \
    >"$art/build.log" 2>&1; then
    echo "FAIL: $name build" >&2
    tail -60 "$art/build.log" >&2 || true
    exit 1
  fi
  local exe
  if ! exe="$(resolve_exe "$name" "$art" "$art/build.log")"; then
    echo "FAIL: $name missing executable" >&2
    tail -40 "$art/build.log" >&2 || true
    exit 1
  fi
  set +e
  timeout 15 "$exe" >"$art/stdout.txt" 2>"$art/stderr.txt"
  local rc=$?
  set -e
  if [ "$rc" -ne "$expect" ]; then
    echo "FAIL: $name exit=$rc expected=$expect" >&2
    echo "--- stderr ---" >&2
    cat "$art/stderr.txt" >&2 || true
    exit 1
  fi
  echo "[rec-str-abi] $name exit=$rc ok"
}

build_and_check_stderr() {
  local name="$1" src="$2" expect="$3"
  local art="$RUN/$name"
  mkdir -p "$art"
  echo "[rec-str-abi] build $name..."
  if ! "$STAGE0" build "$src" \
    --target linux-x86_64 \
    --toolchain-binding linux-x86_64-to-linux-x86_64-llvm \
    --workspace "$ROOT" \
    --out-dir "$art" \
    >"$art/build.log" 2>&1; then
    echo "FAIL: $name build" >&2
    tail -60 "$art/build.log" >&2 || true
    exit 1
  fi
  local exe
  if ! exe="$(resolve_exe "$name" "$art" "$art/build.log")"; then
    echo "FAIL: $name missing executable" >&2
    exit 1
  fi
  set +e
  timeout 15 "$exe" >"$art/stdout.txt" 2>"$art/stderr.txt"
  local rc=$?
  set -e
  if [ "$rc" -ne "$expect" ]; then
    echo "FAIL: $name exit=$rc expected=$expect" >&2
    cat "$art/stderr.txt" "$art/stdout.txt" >&2 || true
    exit 1
  fi
  # Host-free WriteLn currently uses write(1); accept stdout or stderr markers.
  cat "$art/stdout.txt" "$art/stderr.txt" >"$art/combined.txt" 2>/dev/null || true
  if ! grep -Fq 'status=failure' "$art/combined.txt"; then
    echo "FAIL: $name output missing status=failure" >&2
    cat "$art/combined.txt" >&2 || true
    exit 1
  fi
  if ! grep -Fq 'command=build' "$art/combined.txt"; then
    echo "FAIL: $name output missing command=build" >&2
    cat "$art/combined.txt" >&2 || true
    exit 1
  fi
  if ! grep -Eq 'selector=(build|cli)' "$art/combined.txt"; then
    echo "FAIL: $name output missing selector=build|cli" >&2
    cat "$art/combined.txt" >&2 || true
    exit 1
  fi
  echo "[rec-str-abi] $name exit=$rc output-ok"
}

build_and_run rec_str_field \
  tests/fixtures/compiler-system/rec_str_field.pas 42
build_and_run rec_const_str_sret \
  tests/fixtures/compiler-system/rec_const_str_sret.pas 42
build_and_check_stderr fail_mini_state \
  tests/fixtures/compiler-system/fail_mini_state.pas 1

echo "verify_compiler_rec_str_abi_focused=pass"
echo "claim-level=rec-str-const-sret-fail-mini-not-m2a"