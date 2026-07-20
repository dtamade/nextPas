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
#   ASYNC_WINDOWS_STRICT=1  — fail on any suite fail
#   NEXTPAS_ASYNC_WINDOWS_BEST_EFFORT=1 — force soft even on Windows
#   On Windows hosts, STRICT defaults to 1 unless BEST_EFFORT=1 (Q24B).

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

MODULE_ENTRIES=(
  "async.windows_compile_gate tests/nextpas.core.async/test_async_windows_compile_gate"
  "async.windows_contract tests/nextpas.core.async/test_async_windows_contract"
  "poller.windows_runtime_smoke tests/nextpas.core.io.uring/test_poller_windows_runtime_smoke"
  "reactor.iocp tests/nextpas.core.io.uring/test_reactor_iocp_wine"
  "async.accept_connect_smoke tests/nextpas.core.async/test_async_accept_connect_smoke"
)

pass_count=0
fail_count=0
skip_count=0
failed=()

echo "=== Async Windows native smoke ==="
echo "host=$uname_s is_windows=$is_windows core=$CORE_ROOT strict=$STRICT"
if [[ "$is_windows" -eq 1 ]]; then
  if [[ "$STRICT" == "1" ]]; then
    echo "truth_tier=native-windows-candidate; fail-closed"
  else
    echo "truth_tier=native-windows-candidate; soft (BEST_EFFORT)"
  fi
else
  echo "truth_tier=not-native-windows (non-Windows host; suites may skip or wine-only)"
fi
echo

for entry in "${MODULE_ENTRIES[@]}"; do
  name="${entry%% *}"
  dir="${entry#* }"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP $name : missing directory $dir"
    skip_count=$((skip_count + 1))
    continue
  fi
  echo "=== async-windows: $name ($dir) ==="
  set +e
  out="$(make -C "$dir" clean test 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"
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
if [[ "$is_windows" -eq 1 ]]; then
  echo "truth=async-windows-native-smoke; host=windows; strict=$STRICT; gates_passed=$pass_count; gates_failed=$fail_count"
else
  echo "truth=async-windows-native-smoke; host=non-windows; not-native-claim"
fi

if [[ "$fail_count" -gt 0 ]]; then
  echo "failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
  if [[ "$STRICT" == "1" ]]; then
    exit 1
  fi
  echo "soft: not failing job (STRICT!=1)"
  exit 0
fi

exit 0
