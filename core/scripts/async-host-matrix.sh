#!/usr/bin/env bash
# async-host-matrix.sh
#
# Host-focused async/net smoke gates for CI.
# truth=linux-runtime on Linux full suite; on macOS both kqueue-runtime and
# dial-resolve can be run fail-closed (STRICT=1). Still not full-host async parity.
#
# Usage (cwd = core/ or repo root):
#   ./scripts/async-host-matrix.sh
#   ./core/scripts/async-host-matrix.sh
#
# Env:
#   ASYNC_HOST_STRICT=1  — treat failures as hard fail (default 0 when
#                          NEXTPAS_ASYNC_HOST_BEST_EFFORT=1)
#   ASYNC_HOST_GATES=all|kqueue-runtime|dial-resolve  (default all)
#     all             — resolve + dial + kqueue compile + kqueue runtime
#     kqueue-runtime  — only test_async_kqueue_runtime_smoke
#     dial-resolve    — resolve + dial + kqueue compile (no runtime smoke)

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
GATES="${ASYNC_HOST_GATES:-all}"
if [[ "$BEST_EFFORT" == "1" ]]; then
  STRICT=0
fi

uname_s="$(uname -s 2>/dev/null || echo unknown)"

case "$GATES" in
  all)
    MODULE_ENTRIES=(
      "net.async.resolve tests/nextpas.core.net/test_net_async_resolve"
      "net.async.dial tests/nextpas.core.net/test_net_async_dial"
      "async.kqueue_compile_gate tests/nextpas.core.async/test_async_kqueue_compile_gate"
      "async.kqueue_runtime_smoke tests/nextpas.core.async/test_async_kqueue_runtime_smoke"
      "async.accept_connect_smoke tests/nextpas.core.async/test_async_accept_connect_smoke"
      "net.async.udp tests/nextpas.core.net/test_net_async_udp"
      "net.async.pool tests/nextpas.core.net/test_net_async_pool"
    )
    ;;
  kqueue-runtime)
    MODULE_ENTRIES=(
      "async.kqueue_runtime_smoke tests/nextpas.core.async/test_async_kqueue_runtime_smoke"
    )
    ;;
  dial-resolve)
    MODULE_ENTRIES=(
      "net.async.resolve tests/nextpas.core.net/test_net_async_resolve"
      "net.async.dial tests/nextpas.core.net/test_net_async_dial"
      "async.kqueue_compile_gate tests/nextpas.core.async/test_async_kqueue_compile_gate"
      "async.accept_connect_smoke tests/nextpas.core.async/test_async_accept_connect_smoke"
    )
    ;;
  *)
    echo "error: unknown ASYNC_HOST_GATES=$GATES (all|kqueue-runtime|dial-resolve)" >&2
    exit 2
    ;;
esac

pass_count=0
fail_count=0
skip_count=0
failed=()

echo "=== Async host matrix ==="
echo "host=$uname_s core=$CORE_ROOT best_effort=$BEST_EFFORT strict=$STRICT gates=$GATES"
echo "truth: linux-runtime (when green on Linux); macos kqueue-runtime can be fail-closed"
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
  out="$(make -C "$dir" clean test 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"

  # Darwin/FreeBSD: kqueue runtime must prove host-runtime pass, not skip.
  if [[ "$name" == "async.kqueue_runtime_smoke" ]]; then
    if [[ "$uname_s" == "Darwin" || "$uname_s" == "FreeBSD" ]]; then
      if ! printf '%s\n' "$out" | grep -q 'kqueue-runtime-smoke=pass'; then
        echo "FAIL $name : expected kqueue-runtime-smoke=pass on $uname_s"
        fail_count=$((fail_count + 1))
        failed+=("$name (missing pass marker on $uname_s)")
        echo
        continue
      fi
      if printf '%s\n' "$out" | grep -q 'kqueue-runtime-smoke=skip'; then
        echo "FAIL $name : skip not allowed on $uname_s"
        fail_count=$((fail_count + 1))
        failed+=("$name (skip on $uname_s)")
        echo
        continue
      fi
    fi
  fi

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
echo "truth=async-host-matrix; gates=$GATES; gates_passed=$pass_count; gates_failed=$fail_count"

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
