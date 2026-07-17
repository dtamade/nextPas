#!/usr/bin/env bash
# platform-macos-ci-matrix.sh
#
# Real macOS/Darwin host CI matrix (not best-effort whole suite).
# Named focused gates for ROADMAP D2.b; fail-closed.
#
# Usage (cwd = core/ or repo root):
#   ./scripts/platform-macos-ci-matrix.sh
#   ./core/scripts/platform-macos-ci-matrix.sh
#
# Evidence: truth=macos-focused-runtime for the documented gate set only.
# Not full-host macOS parity. Promote goal-tree rows only via ROADMAP D2.c.

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

# Documented D2.b set (ROADMAP): time, sync, thread, files, path, env, error, socket.
MODULE_ENTRIES=(
  "platform.time tests/nextpas.core.platform.time/test_platform_time_helpers"
  "platform.sync tests/nextpas.core.platform.sync/test_platform_sync"
  "platform.thread tests/nextpas.core.platform.thread/test_platform_thread"
  "platform.files tests/nextpas.core.platform.files/test_platform_files"
  "platform.path tests/nextpas.core.platform.path/test_platform_path"
  "platform.env tests/nextpas.core.platform.env/test_platform_env"
  "platform.error tests/nextpas.core.platform.error/test_platform_error"
  "platform.socket tests/nextpas.core.platform.socket/test_platform_socket"
)

pass_count=0
fail_count=0
failed=()

echo "=== Platform macOS CI Matrix (real host) ==="
echo "truth=macos-focused-runtime; documented 8-gate set; not full-host macOS parity"
echo "core=$CORE_ROOT"
echo "fpc=$(command -v fpc 2>/dev/null || true)"
fpc -iV 2>/dev/null || true
fpc -iTP -iTO 2>/dev/null || true
echo

# Fail closed if FPC cannot resolve the System unit (common macOS trunk cfg footgun).
probe_dir="$(mktemp -d)"
trap 'rm -rf "$probe_dir"' EXIT
cat >"$probe_dir/macos_fpc_probe.pas" <<'EOF'
program macos_fpc_probe;
begin
  WriteLn('macos-fpc-probe-ok');
end.
EOF
if ! (cd "$probe_dir" && fpc -MObjFPC -FE"$probe_dir" macos_fpc_probe.pas >/dev/null 2>&1); then
  echo "FAIL toolchain: fpc cannot compile a minimal program (System unit / fpc.cfg)"
  echo "hint: ensure fpc.cfg lives next to the compiler and -Fu points at units/<cpu>-darwin/rtl"
  fpc -vt -FE"$probe_dir" "$probe_dir/macos_fpc_probe.pas" 2>&1 | tail -20 || true
  exit 1
fi
if ! out="$("$probe_dir/macos_fpc_probe" 2>/dev/null | tr -d '\r')" || [[ "$out" != *macos-fpc-probe-ok* ]]; then
  echo "FAIL toolchain: probe binary did not run"
  exit 1
fi
echo "toolchain probe: ok"
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

  echo "=== macos: $name ($dir) ==="
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
echo "truth=macos-focused-runtime; gates_passed=$pass_count; gates_failed=$fail_count; scope=documented-8-gate-set"

if [[ "$fail_count" -gt 0 ]]; then
  echo "failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
  exit 1
fi

exit 0
