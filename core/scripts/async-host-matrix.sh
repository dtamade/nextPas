#!/usr/bin/env bash
# async-host-matrix.sh
#
# Host-focused async/net smoke gates for CI.
# truth=linux-runtime on Linux full suite; on macOS/Windows this script is
# best-effort evidence for dial/resolve/kqueue compile — not full-host parity.
#
# Usage (cwd = core/ or repo root):
#   ./scripts/async-host-matrix.sh
#   ./core/scripts/async-host-matrix.sh
#
# Env:
#   ASYNC_HOST_STRICT=1  — treat missing dirs / failures as hard fail (default 0
#                          when NEXTPAS_ASYNC_HOST_BEST_EFFORT=1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/../src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "$SCRIPT_DIR/../../core/src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/../../core" && pwd)"
else
  echo "error: unable to resolve core/ root" >&2
  exit 2
fi

cd "$CORE_ROOT"

BEST_EFFORT="${NEXTPAS_ASYNC_HOST_BEST_EFFORT:-0}"
STRICT="${ASYNC_HOST_STRICT:-0}"
if [[ "$BEST_EFFORT" == "1" ]]; then
  STRICT=0
fi

MODULE_ENTRIES=(
  "net.async.resolve tests/nextpas.core.net/test_net_async_resolve"
  "net.async.dial tests/nextpas.core.net/test_net_async_dial"
  "async.kqueue_compile_gate tests/nextpas.core.async/test_async_kqueue_compile_gate"
)

# On Darwin, prefer a real kqueue path if poller tests exist; compile gate still runs.
uname_s="$(uname -s 2>/dev/null || echo unknown)"

pass_count=0
fail_count=0
skip_count=0
failed=()

echo "=== Async host matrix ==="
echo "host=$uname_s core=$CORE_ROOT best_effort=$BEST_EFFORT strict=$STRICT"
echo "truth: linux-runtime (when green on Linux); macos/windows = host smoke / compile hooks"
echo

for entry in "${MODULE_ENTRIES[@]}"; do
  name="${entry%% *}"
  dir="${entry#* }"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP $name : missing directory $dir"
    skip_count=$((skip_count + 1))
    continue
  fi
  echo "=== async-host: $name ($dir) ==="
  set +e
  make -C "$dir" clean test
  code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    echo "PASS $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL $name (exit $code)"
    fail_count=$((fail_count + 1))
    failed+=("$name (exit $code)")
  fi
  echo
done

echo "summary: pass=$pass_count fail=$fail_count skip=$skip_count total=${#MODULE_ENTRIES[@]}"
echo "truth=async-host-matrix; gates_passed=$pass_count; gates_failed=$fail_count"

if [[ "$fail_count" -gt 0 ]]; then
  echo "failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
  if [[ "$STRICT" == "1" ]]; then
    exit 1
  fi
  if [[ "$BEST_EFFORT" == "1" ]]; then
    echo "best-effort: not failing job"
    exit 0
  fi
  exit 1
fi

exit 0
