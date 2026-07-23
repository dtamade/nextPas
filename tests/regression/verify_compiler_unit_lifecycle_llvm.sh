#!/usr/bin/env bash
# verify_compiler_unit_lifecycle_llvm.sh — host-free executable proof for
# tests/compiler/pass/unit_lifecycle_pass.pas under LLVM binding.
#
# Proves store-value width cast (call i64 → store i32 trunc) on the multi-unit
# lifecycle fixture: init sets InitCount=42; main assigns Count:=GetInitCount.
# claim-level=unit-lifecycle-llvm-executable-not-ledger-raise
# Requires true LLVM binding — host FPC green is not acceptable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="${NEXTPAS_UNIT_LIFECYCLE_STAGE0:-$REPO_ROOT/build/stage0-bootstrap/nextpas}"
TARGET="${NEXTPAS_UNIT_LIFECYCLE_TARGET:-linux-x86_64}"
# Host-free unit lifecycle gates: require --toolchain-binding …-llvm
# (default nextpas build = fpc-stage0-host is NOT host-free).
BINDING="${NEXTPAS_UNIT_LIFECYCLE_BINDING:-linux-x86_64-to-linux-x86_64-llvm}"
RUNTIME_LIB="${NEXTPAS_UNIT_LIFECYCLE_RUNTIME_LIB:-$REPO_ROOT/build/runtime/$TARGET/libnprt.a}"
FIXTURE="$REPO_ROOT/tests/compiler/pass/unit_lifecycle_pass.pas"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/np-unit-lifecycle-llvm.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -x "$STAGE0" ]]; then
  echo "unit-lifecycle-llvm-failure=missing-stage0 path=$STAGE0" >&2
  exit 1
fi
if [[ ! -f "$RUNTIME_LIB" ]]; then
  echo "unit-lifecycle-llvm-failure=missing-runtime path=$RUNTIME_LIB (make -C rtl/runtime)" >&2
  exit 1
fi
if [[ ! -f "$FIXTURE" ]]; then
  echo "unit-lifecycle-llvm-failure=missing-fixture path=$FIXTURE" >&2
  exit 1
fi
case "$BINDING" in
  *llvm*) ;;
  *)
    echo "unit-lifecycle-llvm-failure=binding-not-llvm binding=$BINDING" >&2
    echo "  host FPC path is not host-free evidence; refuse silent fpc-stage0-host" >&2
    exit 1
    ;;
esac

set +e
"$STAGE0" build "$FIXTURE" \
  --target "$TARGET" \
  --toolchain-binding "$BINDING" \
  --workspace "$REPO_ROOT" \
  --out-dir "$WORK" >"$WORK/build.stdout" 2>"$WORK/build.stderr"
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  echo "unit-lifecycle-llvm-failure=build-exit=$RC" >&2
  rg -n "error:|human-summary=|failure-kind=" "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null | head -40 >&2 || true
  LL="$REPO_ROOT/.nextpas/cache/backend/$TARGET/unit_lifecycle_pass.ll"
  if [[ -f "$LL" ]]; then
    echo "unit-lifecycle-llvm-ll=$LL" >&2
    opt -O2 -o /dev/null "$LL" 2>&1 | head -20 >&2 || true
  fi
  exit 1
fi

# Anti-masquerade: build transcript must show nextPas LLVM primary tool, not host FPC.
if ! rg -q 'backend-family=llvm' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-lifecycle-llvm-failure=backend-family-not-llvm" >&2
  exit 1
fi
if ! rg -q 'primary-tool-profile-id=llvm-stable' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-lifecycle-llvm-failure=primary-tool-not-llvm-stable" >&2
  exit 1
fi
if rg -q 'primary-tool-profile-id=fpc-stage0-host' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-lifecycle-llvm-failure=silent-host-fpc-masquerade" >&2
  exit 1
fi
if ! rg -q 'llvm-toolchain-status=ready' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-lifecycle-llvm-failure=llvm-toolchain-not-ready" >&2
  exit 1
fi

# IR evidence: store of call result must go through trunc (or matching-width cast).
LL=""
for cand in \
  "$REPO_ROOT/.nextpas/cache/backend/$TARGET/unit_lifecycle_pass.ll" \
  "$WORK/unit_lifecycle_pass.ll"
do
  if [[ -f "$cand" ]]; then
    LL="$cand"
    break
  fi
done
if [[ -z "$LL" || ! -f "$LL" ]]; then
  echo "unit-lifecycle-llvm-failure=missing-ll" >&2
  exit 1
fi
if ! rg -q 'call i64 @GetInitCount' "$LL"; then
  echo "unit-lifecycle-llvm-failure=missing-GetInitCount-call" >&2
  exit 1
fi
if ! rg -q 'trunc i64 .* to i32' "$LL"; then
  echo "unit-lifecycle-llvm-failure=missing-i64-to-i32-trunc-before-store" >&2
  exit 1
fi
if ! rg -q 'store i32 .*@g_Count' "$LL"; then
  echo "unit-lifecycle-llvm-failure=missing-store-i32-Count" >&2
  exit 1
fi
if ! rg -q 'np_unit_init_test_unit_lifecycle|np_unit_init_.*test_unit_lifecycle' "$LL"; then
  # accept either mangling; require some unit init for the support unit
  if ! rg -q 'define .*@np_unit_init_' "$LL"; then
    echo "unit-lifecycle-llvm-failure=missing-unit-init-define" >&2
    exit 1
  fi
fi

OUT="$WORK/unit_lifecycle_pass"
if [[ ! -f "$OUT" ]]; then
  echo "unit-lifecycle-llvm-failure=missing-binary path=$OUT" >&2
  exit 1
fi
chmod +x "$OUT" 2>/dev/null || true

set +e
"$OUT" >"$WORK/run.stdout" 2>"$WORK/run.stderr"
EX=$?
set -e
if [[ $EX -ne 0 ]]; then
  echo "unit-lifecycle-llvm-failure=exit-code expected=0 got=$EX" >&2
  cat "$WORK/run.stdout" "$WORK/run.stderr" >&2 || true
  exit 1
fi
if ! rg -q 'OK: init executed, count=42' "$WORK/run.stdout"; then
  echo "unit-lifecycle-llvm-failure=stdout-oracle-missing" >&2
  cat "$WORK/run.stdout" >&2 || true
  exit 1
fi

echo "unit-lifecycle-llvm-ok=0 binding=$BINDING primary=llvm-stable claim-level=host-free-executable-not-ledger-raise"