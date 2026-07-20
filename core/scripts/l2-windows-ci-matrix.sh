#!/usr/bin/env bash
# l2-windows-ci-matrix.sh
#
# L2 process/fs/path/env real Windows host min-set (not Wine).
# Same suite directories as wine 最小生产集, run with native
# `make clean test` so {$IFDEF NEXTPAS_WINDOWS} paths execute on the host.
#
# Usage (cwd = core/ or repo root):
#   ./scripts/l2-windows-ci-matrix.sh
#   ./core/scripts/l2-windows-ci-matrix.sh
#
# Evidence: truth=host-windows for this documented 5-suite min set only.
# See core/docs/process/WIN.md · ROADMAP M3.

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

# Align with core/tests/run_l2_wine_min_set.sh suite list (M2-W4).
MODULE_ENTRIES=(
  "l2.process tests/nextpas.core.process/test_process_wine"
  "l2.fs tests/nextpas.core.fs/test_fs_wine"
  "l2.fs.watch tests/nextpas.core.fs/test_fs_watch_wine"
  "l2.path tests/nextpas.core.path/test_path_wine"
  "l2.os.env tests/nextpas.core.os.env/test_os_env_wine"
)

pass_count=0
fail_count=0
failed=()

echo "=== L2 Windows CI Matrix (real host min-set) ==="
echo "truth=host-windows; 5-suite min production set; not full-host Windows parity"
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

  echo "=== real-windows L2: $name ($dir target=test) ==="
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
echo "truth=host-windows; gates_passed=$pass_count; gates_failed=$fail_count; scope=l2-min-production-set-5"

if [[ "$fail_count" -gt 0 ]]; then
  echo "failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
  exit 1
fi

exit 0
