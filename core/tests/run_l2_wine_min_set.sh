#!/usr/bin/env bash
# L2 process/fs/path/env wine 最小生产集（M2-W4）
# truth=wine-runtime-smoke；≠ 真 Windows host（见 core/docs/process/WIN.md）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

suites=(
  core/tests/nextpas.core.process/test_process_wine
  core/tests/nextpas.core.fs/test_fs_wine
  core/tests/nextpas.core.fs/test_fs_watch_wine
  core/tests/nextpas.core.path/test_path_wine
  core/tests/nextpas.core.os.env/test_os_env_wine
)

echo "=== L2 wine 最小生产集 (5 suites) ==="
echo "truth=wine-runtime-smoke; not real Windows host"
echo "root=$ROOT"
echo

failed=0
for d in "${suites[@]}"; do
  echo "----- $d -----"
  if ! make -C "$d" wine-runtime-smoke; then
    echo "FAIL: $d" >&2
    failed=1
  fi
  echo
done

if [[ "$failed" -ne 0 ]]; then
  echo "L2 wine min set: FAILED" >&2
  exit 1
fi

echo "L2 wine min set: OK (process 11 + fs 4 + watch 3 + path 4 + env 3 = 25)"
