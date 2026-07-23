#!/usr/bin/env bash
# Batch 26: multi-arg WriteLn + inline string sret (AState-like Fail shape).
# Batch 28: Fail diagnostic lines must land on stderr (fd 2), not combined lucky-green.
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
# Batch 28: require Fail lines on stderr (fd 2); stdout must not carry them.
require_stderr_line() {
  local needle="$1" note="${2:-}"
  if ! grep -Fq "$needle" "$art/stderr.txt"; then
    echo "FAIL: $name stderr missing $needle${note:+ ($note)}" >&2
    echo "--- stdout ---" >&2
    cat "$art/stdout.txt" >&2 || true
    echo "--- stderr ---" >&2
    cat "$art/stderr.txt" >&2 || true
    exit 1
  fi
  if grep -Fq "$needle" "$art/stdout.txt"; then
    echo "FAIL: $name stdout leaked $needle (expected fd 2 only)" >&2
    cat "$art/stdout.txt" >&2 || true
    exit 1
  fi
}
require_stderr_line 'status=failure'
require_stderr_line 'command=build'
require_stderr_line 'selector=build'
# Post-sret field multi-arg proves AState ptr slot was not clobbered.
require_stderr_line 'command2=build' 'sret clobber?'
require_stderr_line 'human-summary=invalid-arguments'
require_stderr_line 'failure-kind=invalid-arguments'
echo "[astatestr-fail] $name exit=$rc stderr-fd2-ok"
echo "verify_compiler_astatestr_fail_focused=pass"
echo "claim-level=astatestr-selector-truth-fd2"