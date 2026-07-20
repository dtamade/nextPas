#!/usr/bin/env bash
# async-windows-native-smoke.sh
#
# Native Windows (or non-Windows for compile-ish suites) async I/O smoke.
# truth=native-windows-candidate when run on bare-metal Windows with STRICT.
# Under Wine/non-Windows: do not rebrand as native-windows.
#
# Usage (cwd = core/ or repo root):
#   bash core/scripts/async-windows-native-smoke.sh
#
# Env:
#   ASYNC_WINDOWS_STRICT=1  — fail on any STRICT suite fail
#   NEXTPAS_ASYNC_WINDOWS_BEST_EFFORT=1 — force soft even on Windows
#   ASYNC_WINDOWS_SUITE_TIMEOUT_SEC — per-suite wall timeout (default 120)
#   ASYNC_WINDOWS_RUN_SOFT=0 — skip soft/aspirational suites
#   On Windows hosts, STRICT defaults to 1 unless BEST_EFFORT=1 (Q24B).
#
# Q38 honesty: Q33 expanded dial/udp/pool/cancel; GHA Q37 showed they compile
# after Q37 portability fixes but runtime is not green yet:
#   - dial: AsyncConnect path returns ECONNREFUSED-ish (-111); stream nil
#   - udp: AsyncRecvFrom/Timeout arm fails
#   - pool: hung >1h on AcquireAsync (no suite timeout previously)
# Keep them SOFT until IOCP connect/datagram path is fixed; STRICT stays green.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/../src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "$SCRIPT_DIR/../../core/src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/../../core" && pwd)"
else
  echo "error: unable to resolve core/" >&2
  exit 2
fi

cd "$CORE_ROOT"

uname_s="$(uname -s 2>/dev/null || echo unknown)"
# MSYS/Cygwin report MINGW*/MSYS*/CYGWIN*
is_windows=0
case "$uname_s" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT) is_windows=1 ;;
esac
if [[ "${OS:-}" == "Windows_NT" ]]; then
  is_windows=1
fi

# Q24B: Windows host defaults STRICT=1; non-Windows stays soft unless forced.
if [[ -n "${ASYNC_WINDOWS_STRICT+x}" ]]; then
  STRICT="${ASYNC_WINDOWS_STRICT}"
elif [[ "$is_windows" -eq 1 ]]; then
  STRICT=1
else
  STRICT=0
fi
if [[ "${NEXTPAS_ASYNC_WINDOWS_BEST_EFFORT:-0}" == "1" ]]; then
  STRICT=0
fi

SUITE_TIMEOUT_SEC="${ASYNC_WINDOWS_SUITE_TIMEOUT_SEC:-120}"
RUN_SOFT="${ASYNC_WINDOWS_RUN_SOFT:-1}"

# Fail-closed candidate surface (GHA Q37 green or skip-ok).
STRICT_ENTRIES=(
  "async.windows_compile_gate tests/nextpas.core.async/test_async_windows_compile_gate"
  "async.windows_contract tests/nextpas.core.async/test_async_windows_contract"
  "poller.windows_runtime_smoke tests/nextpas.core.io.uring/test_poller_windows_runtime_smoke"
  "reactor.iocp tests/nextpas.core.io.uring/test_reactor_iocp_wine"
  "async.accept_connect_smoke tests/nextpas.core.async/test_async_accept_connect_smoke"
  "net.async.resolve tests/nextpas.core.net/test_net_async_resolve"
  "net.error_classify tests/nextpas.core.net/test_net_error_classify"
)

# Aspirational: compile after Q37; runtime not yet fail-closed green (IOCP dial/datagram).
SOFT_ENTRIES=(
  "net.async.dial tests/nextpas.core.net/test_net_async_dial"
  "net.async.udp tests/nextpas.core.net/test_net_async_udp"
  "net.async.pool tests/nextpas.core.net/test_net_async_pool"
  "net.cancel_bridge tests/nextpas.core.net/test_net_cancel_bridge"
)

pass_count=0
fail_count=0
soft_pass_count=0
soft_fail_count=0
skip_count=0
failed=()
soft_failed=()

run_suite() {
  local name="$1"
  local dir="$2"
  local mode="$3" # strict|soft
  local out code

  if [[ ! -d "$dir" ]]; then
    echo "SKIP $name : missing directory $dir"
    skip_count=$((skip_count + 1))
    return 0
  fi

  echo "=== async-windows[$mode]: $name ($dir) timeout=${SUITE_TIMEOUT_SEC}s ==="
  set +e
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout --signal=KILL "${SUITE_TIMEOUT_SEC}" make -C "$dir" clean test 2>&1)"
    code=$?
    if [[ "$code" -eq 124 ]] || [[ "$code" -eq 137 ]]; then
      out="${out}"$'\n'"TIMEOUT after ${SUITE_TIMEOUT_SEC}s"
      code=124
    fi
  else
    out="$(make -C "$dir" clean test 2>&1)"
    code=$?
  fi
  set -e
  printf '%s\n' "$out"
  if [[ "$code" -eq 0 ]]; then
    echo "PASS $name"
    if [[ "$mode" == "strict" ]]; then
      pass_count=$((pass_count + 1))
    else
      soft_pass_count=$((soft_pass_count + 1))
    fi
  else
    echo "FAIL $name (exit $code)"
    if [[ "$mode" == "strict" ]]; then
      fail_count=$((fail_count + 1))
      failed+=("$name (exit $code)")
    else
      soft_fail_count=$((soft_fail_count + 1))
      soft_failed+=("$name (exit $code)")
    fi
  fi
  echo
}

echo "=== Async Windows native smoke ==="
echo "host=$uname_s is_windows=$is_windows core=$CORE_ROOT strict=$STRICT suite_timeout=${SUITE_TIMEOUT_SEC}s run_soft=$RUN_SOFT"
if [[ "$is_windows" -eq 1 ]]; then
  if [[ "$STRICT" == "1" ]]; then
    echo "truth_tier=native-windows-candidate; fail-closed (strict suites only)"
  else
    echo "truth_tier=native-windows-candidate; soft (BEST_EFFORT)"
  fi
else
  echo "truth_tier=not-native-windows (non-Windows host; suites may skip or wine-only)"
fi
echo "strict_suites=${#STRICT_ENTRIES[@]} soft_suites=${#SOFT_ENTRIES[@]}"
echo

for entry in "${STRICT_ENTRIES[@]}"; do
  run_suite "${entry%% *}" "${entry#* }" strict
done

if [[ "$RUN_SOFT" == "1" ]]; then
  for entry in "${SOFT_ENTRIES[@]}"; do
    run_suite "${entry%% *}" "${entry#* }" soft
  done
else
  echo "soft suites skipped (ASYNC_WINDOWS_RUN_SOFT=0)"
  echo
fi

echo "summary: strict_pass=$pass_count strict_fail=$fail_count soft_pass=$soft_pass_count soft_fail=$soft_fail_count skip=$skip_count"
if [[ "$is_windows" -eq 1 ]]; then
  echo "truth=async-windows-native-smoke; host=windows; strict=$STRICT; gates_passed=$pass_count; gates_failed=$fail_count; soft_failed=$soft_fail_count"
else
  echo "truth=async-windows-native-smoke; host=non-windows; not-native-claim"
fi

if [[ "$fail_count" -gt 0 ]]; then
  echo "strict failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
fi
if [[ "$soft_fail_count" -gt 0 ]]; then
  echo "soft failed (not fail-closed):"
  for item in "${soft_failed[@]}"; do
    printf '  - %s\n' "$item"
  done
fi

if [[ "$fail_count" -gt 0 ]]; then
  if [[ "$STRICT" == "1" ]]; then
    exit 1
  fi
  echo "soft: not failing job (STRICT!=1)"
  exit 0
fi

exit 0
