#!/usr/bin/env bash
# Batch 27: ErrOutput/StdErr → fd 2; Output/default → fd 1.
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
  echo "[erroutput-fd] building libnprt.a..."
  make -C "$ROOT/rtl/runtime" all
fi
if [ ! -f "$ROOT/build/runtime/linux-x86_64/libnprt.a" ]; then
  echo "FAIL: missing libnprt.a after make -C rtl/runtime" >&2
  exit 2
fi

RUN="${RUN_DIR:-$ROOT/build/erroutput-fd-focused-$$}"
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

name="erroutput_fd_mini"
src="tests/fixtures/compiler-system/erroutput_fd_mini.pas"
art="$RUN/$name"
mkdir -p "$art"
echo "[erroutput-fd] build $name..."
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
if ! grep -Fq 'stdout-marker' "$art/stdout.txt"; then
  echo "FAIL: $name stdout missing stdout-marker" >&2
  cat "$art/stdout.txt" "$art/stderr.txt" >&2 || true
  exit 1
fi
if grep -Fq 'stderr-marker' "$art/stdout.txt"; then
  echo "FAIL: $name stdout leaked stderr-marker (fd routing broken)" >&2
  cat "$art/stdout.txt" >&2 || true
  exit 1
fi
if ! grep -Fq 'stderr-marker' "$art/stderr.txt"; then
  echo "FAIL: $name stderr missing stderr-marker" >&2
  cat "$art/stdout.txt" "$art/stderr.txt" >&2 || true
  exit 1
fi
if ! grep -Fq 'status=failure' "$art/stderr.txt"; then
  echo "FAIL: $name stderr missing status=failure" >&2
  cat "$art/stderr.txt" >&2 || true
  exit 1
fi
if grep -Fq 'status=failure' "$art/stdout.txt"; then
  echo "FAIL: $name stdout leaked status=failure" >&2
  cat "$art/stdout.txt" >&2 || true
  exit 1
fi
echo "[erroutput-fd] $name exit=$rc stdout/stderr-split-ok"
echo "verify_compiler_erroutput_fd_focused=pass"
echo "claim-level=erroutput-fd2-routing"