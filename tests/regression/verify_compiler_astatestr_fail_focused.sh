#!/usr/bin/env bash
# Batch 26: multi-arg WriteLn + inline string sret (AState-like Fail shape).
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
  echo "[astatestr-fail] building libnprt.a..."
  make -C "$ROOT/rtl/runtime" all
fi
if [ ! -f "$ROOT/build/runtime/linux-x86_64/libnprt.a" ]; then
  echo "FAIL: missing libnprt.a after make -C rtl/runtime" >&2
  exit 2
fi

RUN="${RUN_DIR:-$ROOT/build/astatestr-fail-focused-$$}"
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

name="astatestr_fail_mini"
src="tests/fixtures/compiler-system/astatestr_fail_mini.pas"
art="$RUN/$name"
mkdir -p "$art"
echo "[astatestr-fail] build $name..."
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
if [ "$rc" -ne 1 ]; then
  echo "FAIL: $name exit=$rc expected=1" >&2
  cat "$art/stderr.txt" "$art/stdout.txt" >&2 || true
  exit 1
fi
# Host-free WriteLn currently uses write(1); accept stdout or stderr.
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
if ! grep -Fq 'selector=build' "$art/combined.txt"; then
  echo "FAIL: $name output missing selector=build" >&2
  cat "$art/combined.txt" >&2 || true
  exit 1
fi
# Post-sret field multi-arg proves AState ptr slot was not clobbered.
if ! grep -Fq 'command2=build' "$art/combined.txt"; then
  echo "FAIL: $name output missing command2=build (sret clobber?)" >&2
  cat "$art/combined.txt" >&2 || true
  exit 1
fi
if ! grep -Fq 'human-summary=invalid-arguments' "$art/combined.txt"; then
  echo "FAIL: $name output missing human-summary=invalid-arguments" >&2
  cat "$art/combined.txt" >&2 || true
  exit 1
fi
if ! grep -Fq 'failure-kind=invalid-arguments' "$art/combined.txt"; then
  echo "FAIL: $name output missing failure-kind=invalid-arguments" >&2
  cat "$art/combined.txt" >&2 || true
  exit 1
fi
echo "[astatestr-fail] $name exit=$rc output-ok"
echo "verify_compiler_astatestr_fail_focused=pass"
echo "claim-level=astatestr-selector-truth"