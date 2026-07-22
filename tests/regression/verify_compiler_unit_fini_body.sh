#!/usr/bin/env bash
# verify_compiler_unit_fini_body.sh — L2-IR evidence: unit finalization lowers
# to a non-empty np_unit_fini_* body (store), called before process_fini.
#
# claim-level=unit-fini-body-ir-not-kernel-scale
# Requires true LLVM binding — host FPC green is not acceptable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="${NEXTPAS_UNIT_FINI_STAGE0:-$REPO_ROOT/build/stage0-bootstrap/nextpas}"
TARGET="${NEXTPAS_UNIT_FINI_TARGET:-linux-x86_64}"
BINDING="${NEXTPAS_UNIT_FINI_BINDING:-linux-x86_64-to-linux-x86_64-llvm}"
RUNTIME_LIB="${NEXTPAS_UNIT_FINI_RUNTIME_LIB:-$REPO_ROOT/build/runtime/$TARGET/libnprt.a}"
SMOKE="$REPO_ROOT/examples/smoke/llvm_unit_fini_body.pas"
UNIT_ID="mufinileaf"
FINI_SYM="np_unit_fini_${UNIT_ID}"
GLOBAL_MARK="@g_GFiniMark"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/np-unit-fini-body.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -x "$STAGE0" ]]; then
  echo "unit-fini-body-failure=missing-stage0 path=$STAGE0" >&2
  exit 1
fi
if [[ ! -f "$RUNTIME_LIB" ]]; then
  echo "unit-fini-body-failure=missing-runtime path=$RUNTIME_LIB (make -C rtl/runtime)" >&2
  exit 1
fi
if [[ ! -f "$SMOKE" ]]; then
  echo "unit-fini-body-failure=missing-fixture path=$SMOKE" >&2
  exit 1
fi
if [[ ! -f "$REPO_ROOT/units/${TARGET}/MuFiniLeaf.pas" ]]; then
  echo "unit-fini-body-failure=missing-unit MuFiniLeaf for $TARGET" >&2
  exit 1
fi
if ! grep -q 'finalization' "$REPO_ROOT/units/${TARGET}/MuFiniLeaf.pas"; then
  echo "unit-fini-body-failure=MuFiniLeaf must contain finalization section" >&2
  exit 1
fi

echo "=== unit finalization body IR gate ==="
echo "[1/3] host-free build llvm_unit_fini_body..."
set +e
"$STAGE0" build "$SMOKE" \
  --target "$TARGET" \
  --toolchain-binding "$BINDING" \
  --workspace "$REPO_ROOT" \
  --out-dir "$WORK" >"$WORK/build.stdout" 2>"$WORK/build.stderr"
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  echo "unit-fini-body-failure=build-exit=$RC" >&2
  rg -n "error:|human-summary=|failure-kind=" "$WORK/build.stdout" "$WORK/build.stderr" 2>/dev/null | head -40 >&2 || true
  tail -30 "$WORK/build.stderr" >&2 || true
  exit 1
fi

LL=""
for cand in \
  "$REPO_ROOT/.nextpas/cache/backend/$TARGET/llvm_unit_fini_body.ll" \
  "$WORK/llvm_unit_fini_body.ll"
do
  if [[ -f "$cand" ]]; then
    LL="$cand"
    break
  fi
done
if [[ -z "$LL" ]]; then
  LL="$(find "$WORK" "$REPO_ROOT/.nextpas/cache/backend/$TARGET" -name 'llvm_unit_fini_body.ll' 2>/dev/null | head -1 || true)"
fi
if [[ -z "$LL" || ! -f "$LL" ]]; then
  echo "unit-fini-body-failure=missing-ll" >&2
  exit 1
fi
echo "  PASS: build ok ($LL)"

echo "[2/3] assert non-empty $FINI_SYM body (store to $GLOBAL_MARK)..."
# Real unit bodies use `define i64 @... #0`; empty residual stubs use `define internal`.
BODY="$(awk -v sym="@${FINI_SYM}" '
  $0 ~ ("define (internal )?i64 " sym "\\(\\)") { grab=1; print; next }
  grab && (/^define / || /^declare / || /^@/) { exit }
  grab { print }
' "$LL")"
if [[ -z "$BODY" ]]; then
  echo "unit-fini-body-failure=missing-define $FINI_SYM" >&2
  exit 1
fi
if ! echo "$BODY" | grep -q "store .*${GLOBAL_MARK}"; then
  echo "unit-fini-body-failure=$FINI_SYM body has no store to $GLOBAL_MARK (empty stub?)" >&2
  echo "$BODY" >&2
  exit 1
fi
if echo "$BODY" | grep -q 'store ' && echo "$BODY" | grep -q 'ret i64'; then
  :
else
  echo "unit-fini-body-failure=$FINI_SYM body incomplete" >&2
  echo "$BODY" >&2
  exit 1
fi
echo "  PASS: fini body contains store to $GLOBAL_MARK"

echo "[3/3] assert entry (_start) calls $FINI_SYM before process_fini..."
# Current emitter names the entry @_start; recovery used nextpas_program_entry.
START_CHUNK="$(awk '
  /^define i64 @(_start|nextpas_program_entry)\(\)/ { grab=1; print; next }
  grab && /^define / { exit }
  grab { print }
' "$LL")"
FINI_CALL_POS="$(echo "$START_CHUNK" | grep -n "call i64 @${FINI_SYM}()" | head -1 | cut -d: -f1 || true)"
PFINI_POS="$(echo "$START_CHUNK" | grep -n 'call void @np_process_fini()' | head -1 | cut -d: -f1 || true)"
if [[ -z "$FINI_CALL_POS" ]]; then
  echo "unit-fini-body-failure=entry missing call @${FINI_SYM}" >&2
  exit 1
fi
if [[ -z "$PFINI_POS" ]]; then
  echo "unit-fini-body-failure=entry missing process_fini" >&2
  exit 1
fi
if [[ "$FINI_CALL_POS" -ge "$PFINI_POS" ]]; then
  echo "unit-fini-body-failure=unit fini must precede process_fini (fini@$FINI_CALL_POS process@$PFINI_POS)" >&2
  exit 1
fi
echo "  PASS: call order unit_fini before process_fini"

EXE="$WORK/llvm_unit_fini_body"
if [[ -f "$EXE" ]]; then
  chmod +x "$EXE" 2>/dev/null || true
  set +e
  "$EXE" >/dev/null 2>&1
  EC=$?
  set -e
  if [[ "$EC" -ne 1 ]]; then
    echo "unit-fini-body-failure=exit expected=1 got=$EC" >&2
    exit 1
  fi
  echo "  PASS: executable exit 1 (init-only oracle)"
fi

echo "unit-fini-body=pass binding=$BINDING"
echo "claim-level=unit-fini-body-ir-not-kernel-scale"