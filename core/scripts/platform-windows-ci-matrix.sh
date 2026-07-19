#!/usr/bin/env bash
# platform-windows-ci-matrix.sh
#
# Real Windows host CI matrix (not Wine).
# Same suite directories as platform-wine-ci-matrix.sh, run with native
# `make clean test` so {$IFDEF NEXTPAS_WINDOWS} paths execute on the host.
#
# Usage (cwd = core/ or repo root):
#   ./scripts/platform-windows-ci-matrix.sh
#   ./core/scripts/platform-windows-ci-matrix.sh
#
# Evidence: truth=ci-matrix for the documented gate set (ROADMAP D1.d + error expand).
# Scope is the MODULE_ENTRIES list only — not full-host Windows parity.
# 18-gate set = prior 17 + platform.error (pending durable GHA green before promote claims).

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

MODULE_ENTRIES=(
  "platform.time tests/nextpas.core.platform.time/test_platform_time_wine"
  "platform.memory tests/nextpas.core.platform.memory/test_platform_memory_wine"
  "platform.sync tests/nextpas.core.platform.sync/test_platform_sync_wine"
  "platform.thread tests/nextpas.core.platform.thread/test_platform_thread_wine"
  "platform.io tests/nextpas.core.platform.io/test_platform_io_wine"
  "platform.process tests/nextpas.core.platform.process/test_platform_process_wine"
  "platform.files tests/nextpas.core.platform.files/test_platform_files_wine"
  "platform.fs tests/nextpas.core.platform.fs/test_platform_fs_wine"
  "platform.path tests/nextpas.core.platform.path/test_platform_path_wine"
  "platform.env tests/nextpas.core.platform.env/test_platform_env_wine"
  "platform.mmap tests/nextpas.core.platform.mmap/test_platform_mmap_wine"
  "platform.random tests/nextpas.core.platform.random/test_platform_random_wine"
  "platform.socket tests/nextpas.core.platform.socket/test_platform_socket_wine"
  "platform.error tests/nextpas.core.platform.error/test_platform_error_wine"
  "io.reactor.iocp tests/nextpas.core.io.uring/test_reactor_iocp_wine"
  "poller.windows_runtime_smoke tests/nextpas.core.io.uring/test_poller_windows_runtime_smoke"
  "platform.io.windows_real tests/nextpas.core.platform/test_platform_io_windows_real"
  "platform.socket.windows_real tests/nextpas.core.platform.socket/test_platform_socket_windows_real"
)

pass_count=0
fail_count=0
failed=()

echo "=== Platform Windows CI Matrix (real host) ==="
echo "truth=ci-matrix; documented 18-gate set (candidate until GHA green); not full-host Windows parity"
echo "core=$CORE_ROOT"
echo "fpc=$(command -v fpc 2>/dev/null || true)"
fpc -iV 2>/dev/null || true
fpc -iTP -iTO 2>/dev/null || true
echo

for entry in "${MODULE_ENTRIES[@]}"; do
  name="${entry%% *}"
  dir="${entry#* }"
  if [[ ! -d "$dir" ]]; then
    echo "FAIL $name : missing directory $dir"
    fail_count=$((fail_count + 1))
    failed+=("$name (missing $dir)")
    continue
  fi

  echo "=== real-windows: $name ($dir) ==="
  if make -C "$dir" clean test; then
    echo "PASS $name"
    pass_count=$((pass_count + 1))
  else
    code=$?
    echo "FAIL $name (exit $code)"
    fail_count=$((fail_count + 1))
    failed+=("$name (exit $code)")
  fi
  echo
done

echo "summary: pass=$pass_count fail=$fail_count total=${#MODULE_ENTRIES[@]}"
echo "truth=ci-matrix; gates_passed=$pass_count; gates_failed=$fail_count; scope=documented-18-gate-set"

if [[ "$fail_count" -gt 0 ]]; then
  echo "failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
  exit 1
fi

exit 0
