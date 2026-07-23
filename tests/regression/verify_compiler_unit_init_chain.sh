#!/usr/bin/env bash
# Focused host-free multi-unit initialization evidence (Slice A).
# REQUIRES --toolchain-binding …-llvm; default stage0 build is host FPC (not host-free).
# Expect Halt(33): leaf init sets GMuAcc=3, mid adds 30.
# Requires true LLVM binding — host FPC green is not acceptable.
# claim-level=unit-init-chain-host-free-executable-not-ledger-raise
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="${NEXTPAS_UNIT_INIT_STAGE0:-$REPO_ROOT/build/stage0-bootstrap/nextpas}"
TARGET="${NEXTPAS_UNIT_INIT_TARGET:-linux-x86_64}"
BINDING="${NEXTPAS_UNIT_INIT_BINDING:-linux-x86_64-to-linux-x86_64-llvm}"
RUNTIME_LIB="${NEXTPAS_UNIT_INIT_RUNTIME_LIB:-$REPO_ROOT/build/runtime/$TARGET/libnprt.a}"
SMOKE="$REPO_ROOT/examples/smoke/llvm_unit_init_chain.pas"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/np-unit-init-chain.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -x "$STAGE0" ]]; then
  echo "unit-init-chain-failure=missing-stage0 path=$STAGE0" >&2
  exit 1
fi
if [[ ! -f "$RUNTIME_LIB" ]]; then
  echo "unit-init-chain-failure=missing-runtime path=$RUNTIME_LIB (make -C rtl/runtime)" >&2
  exit 1
fi
if [[ ! -f "$SMOKE" ]]; then
  echo "unit-init-chain-failure=missing-fixture path=$SMOKE" >&2
  exit 1
fi
case "$BINDING" in
  *llvm*) ;;
  *)
    echo "unit-init-chain-failure=binding-not-llvm binding=$BINDING" >&2
    echo "  host FPC path is not host-free evidence; refuse silent fpc-stage0-host" >&2
    exit 1
    ;;
esac

set +e
"$STAGE0" build "$SMOKE" \
  --target "$TARGET" \
  --toolchain-binding "$BINDING" \
  --workspace "$REPO_ROOT" \
  --out-dir "$WORK" >"$WORK/build.stdout" 2>"$WORK/build.stderr"
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  echo "unit-init-chain-failure=build-exit=$RC" >&2
  # Surface IR/opt diagnostics if present
  rg -n "error:|human-summary=|failure-kind=" "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null | head -40 >&2 || true
  LL="$REPO_ROOT/.nextpas/cache/backend/$TARGET/llvm_unit_init_chain.ll"
  if [[ -f "$LL" ]]; then
    echo "unit-init-chain-ll=$LL" >&2
    opt -O2 -o /dev/null "$LL" 2>&1 | head -20 >&2 || true
  fi
  exit 1
fi

# Anti-masquerade: build transcript must show nextPas LLVM primary tool, not host FPC.
if ! rg -q 'backend-family=llvm' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-init-chain-failure=backend-family-not-llvm" >&2
  exit 1
fi
if ! rg -q 'primary-tool-profile-id=llvm-stable' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-init-chain-failure=primary-tool-not-llvm-stable" >&2
  exit 1
fi
if rg -q 'primary-tool-profile-id=fpc-stage0-host' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-init-chain-failure=silent-host-fpc-masquerade" >&2
  exit 1
fi
if ! rg -q 'llvm-toolchain-status=ready' "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null; then
  echo "unit-init-chain-failure=llvm-toolchain-not-ready" >&2
  exit 1
fi

OUT="$WORK/llvm_unit_init_chain"
if [[ ! -f "$OUT" ]]; then
  echo "unit-init-chain-failure=missing-binary path=$OUT" >&2
  exit 1
fi
chmod +x "$OUT" 2>/dev/null || true

set +e
"$OUT"
EX=$?
set -e
if [[ $EX -ne 33 ]]; then
  echo "unit-init-chain-failure=exit-code expected=33 got=$EX" >&2
  exit 1
fi

echo "unit-init-chain-ok=33 binding=$BINDING primary=llvm-stable claim-level=host-free-executable-not-ledger-raise"