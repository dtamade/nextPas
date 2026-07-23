#!/usr/bin/env bash
# verify_compiler_body_seed_budget.sh — SeedFunctionBodies reachability budget
#
# Fixture: llvm_body_seed_budget (multi-unit synthetic flood: BsFloodMid→BsFloodLeaf).
# ~120 dead free functions + live path; program only calls LiveMid.
# Assert body-seed-reachability encoded << registered and build/run Halt(7).
#
# claim-level=body-seed-reachability-partial-not-m2a
# Residual: llvm_kernel_unit_sdb / nextpas.core.text.conv host-free hang is separate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="${NEXTPAS_BODY_SEED_STAGE0:-$REPO_ROOT/build/stage0-bootstrap/nextpas}"
TARGET="${NEXTPAS_BODY_SEED_TARGET:-linux-x86_64}"
BINDING="${NEXTPAS_BODY_SEED_BINDING:-linux-x86_64-to-linux-x86_64-llvm}"
SMOKE="$REPO_ROOT/examples/smoke/llvm_body_seed_budget.pas"
WORK_ROOT="${NEXTPAS_BODY_SEED_WORK_ROOT:-$REPO_ROOT/build/body-seed-budget}"
# Require at least 4x reduction on encoded vs registered (encoded/registered < 0.25)
# and hard cap far below a full dead-body flood (~120 dead free funcs alone).
MAX_ENCODED_RATIO="0.25"
MAX_ENCODED_ABS=40
# LiveMid returns LiveLeaf (7)
EXPECTED_EXIT=7
# Floor: flood units must contribute enough registered bodies for a meaningful ratio.
MIN_REGISTERED=80

if [ ! -x "$STAGE0" ]; then
  echo "FAIL: stage0 not executable: $STAGE0" >&2
  exit 1
fi
if [ ! -f "$SMOKE" ]; then
  echo "FAIL: missing $SMOKE" >&2
  exit 1
fi

mkdir -p "$WORK_ROOT"
RUN_DIR="$(mktemp -d "$WORK_ROOT/run.XXXXXX")"
trap 'rm -rf "$RUN_DIR"' EXIT HUP INT TERM

echo "=== body-seed reachability budget (llvm_body_seed_budget) ==="
echo "[1/3] host-free build..."
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0" build "$SMOKE" \
  --target "$TARGET" \
  --toolchain-binding "$BINDING" \
  --out-dir "$RUN_DIR/out" \
  --workspace "$REPO_ROOT" >"$RUN_DIR/build.log" 2>&1; then
  echo "FAIL: build failed" >&2
  tail -40 "$RUN_DIR/build.log" >&2
  exit 1
fi
echo "  PASS: build ok"

echo "[2/3] parse body-seed-reachability line..."
# Use last summary line (second SeedFunctionBodies pass after unit lifecycle)
LINE="$(grep 'body-seed-reachability registered=' "$RUN_DIR/build.log" | tail -1 || true)"
if [ -z "$LINE" ]; then
  echo "FAIL: missing body-seed-reachability summary in stderr log" >&2
  tail -30 "$RUN_DIR/build.log" >&2
  exit 1
fi
echo "  $LINE"
REGISTERED="$(echo "$LINE" | sed -n 's/.*registered=\([0-9]*\).*/\1/p')"
NEEDED="$(echo "$LINE" | sed -n 's/.*needed=\([0-9]*\).*/\1/p')"
ENCODED="$(echo "$LINE" | sed -n 's/.*encoded=\([0-9]*\).*/\1/p')"
if [ -z "$REGISTERED" ] || [ -z "$ENCODED" ] || [ "$REGISTERED" -le 0 ]; then
  echo "FAIL: could not parse registered/encoded from: $LINE" >&2
  exit 1
fi
if [ "$REGISTERED" -lt "$MIN_REGISTERED" ]; then
  echo "FAIL: registered=$REGISTERED < min $MIN_REGISTERED (flood units not attached?)" >&2
  exit 1
fi
if [ "$ENCODED" -gt "$MAX_ENCODED_ABS" ]; then
  echo "FAIL: encoded=$ENCODED exceeds abs cap $MAX_ENCODED_ABS (dead flood not pruned)" >&2
  exit 1
fi
# ratio encoded/registered via awk
RATIO_OK="$(awk -v e="$ENCODED" -v r="$REGISTERED" -v max="$MAX_ENCODED_RATIO" \
  'BEGIN { if (r <= 0) exit 1; if ((e / r) < max + 0.0) print "yes"; else print "no" }')"
if [ "$RATIO_OK" != "yes" ]; then
  echo "FAIL: encoded/registered=$ENCODED/$REGISTERED not < $MAX_ENCODED_RATIO" >&2
  exit 1
fi
if [ "$ENCODED" -gt "$NEEDED" ]; then
  echo "FAIL: encoded=$ENCODED > needed=$NEEDED" >&2
  exit 1
fi
echo "  PASS: encoded=$ENCODED registered=$REGISTERED needed=$NEEDED (ratio ok, abs cap ok)"

echo "[3/3] executable exit $EXPECTED_EXIT..."
EXE="$(find "$RUN_DIR/out" -type f -executable -name 'llvm_body_seed_budget' | head -1)"
if [ -z "$EXE" ]; then
  EXE="$(find "$RUN_DIR" -type f -executable -name 'llvm_body_seed_budget' | head -1)"
fi
if [ -z "$EXE" ]; then
  echo "FAIL: missing executable" >&2
  exit 1
fi
set +e
"$EXE" >/dev/null 2>&1
EC=$?
set -e
if [ "$EC" -ne "$EXPECTED_EXIT" ]; then
  echo "FAIL: exit expected $EXPECTED_EXIT got $EC" >&2
  exit 1
fi
echo "  PASS: executable exit $EXPECTED_EXIT"

echo "body-seed-budget=pass"
echo "body-seed-encoded=$ENCODED"
echo "body-seed-registered=$REGISTERED"
echo "claim-level=body-seed-reachability-partial-not-m2a"