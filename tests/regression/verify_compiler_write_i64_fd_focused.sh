#!/usr/bin/env bash
# Batch 29: write_i64_decimal(value, fd) — integer WriteLn to stderr (fd 2).
# Not M2-A. claim-level set at end.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

STAGE0="${STAGE0:-$ROOT/build/stage0-bootstrap/nextpas}"
if [ ! -x "$STAGE0" ]; then
  echo "FAIL: missing stage0 nextpas at $STAGE0 (make rebuild-compiler)" >&2
  exit 2
fi

if [ ! -f "$ROOT/build/runtime/linux-x86_64/libnprt.a" ]; then
  echo "[write-i64-fd] building libnprt.a..."
  make -C "$ROOT/rtl/runtime" all
fi
if [ ! -f "$ROOT/build/runtime/linux-x86_64/libnprt.a" ]; then
  echo "FAIL: missing libnprt.a after make -C rtl/runtime" >&2
  exit 2
fi

RUN="${RUN_DIR:-$ROOT/build/write-i64-fd-focused-$$}"
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

name="write_i64_fd_mini"
src="tests/fixtures/compiler-system/write_i64_fd_mini.pas"
art="$RUN/$name"
mkdir -p "$art"
echo "[write-i64-fd] build $name..."
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
if ! exe="$(resolve_exe "$name" "$art" "$art/build.log")"; then
  echo "FAIL: $name missing executable" >&2
  exit 1
fi
set +e
timeout 15 "$exe" >"$art/stdout.txt" 2>"$art/stderr.txt"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "FAIL: $name exit=$rc expected=0" >&2
  cat "$art/stderr.txt" "$art/stdout.txt" >&2 || true
  exit 1
fi
# Integer 42 must land on stdout (fd 1); 7 on stderr (fd 2).
if ! grep -Fq '42' "$art/stdout.txt"; then
  echo "FAIL: $name stdout missing 42" >&2
  cat "$art/stdout.txt" "$art/stderr.txt" >&2 || true
  exit 1
fi
if grep -Fq '7' "$art/stdout.txt"; then
  echo "FAIL: $name stdout leaked 7 (integer stderr routing broken)" >&2
  cat "$art/stdout.txt" >&2 || true
  exit 1
fi
if ! grep -Fq '7' "$art/stderr.txt"; then
  echo "FAIL: $name stderr missing 7" >&2
  cat "$art/stdout.txt" "$art/stderr.txt" >&2 || true
  exit 1
fi
if grep -Fq '42' "$art/stderr.txt"; then
  echo "FAIL: $name stderr leaked 42" >&2
  cat "$art/stderr.txt" >&2 || true
  exit 1
fi
echo "[write-i64-fd] $name exit=$rc stdout/stderr-int-split-ok"
echo "verify_compiler_write_i64_fd_focused=pass"
echo "claim-level=write-i64-decimal-fd"