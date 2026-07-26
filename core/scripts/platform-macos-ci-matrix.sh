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

# Optional GHA toolchain hints (set by core-ci test-macos Setup).
if [[ -n "${NEXTPAS_FPC_UNITS:-}" ]]; then
  WRAP="$CORE_ROOT/build/macos-fpc-wrap.sh"
  mkdir -p "$(dirname "$WRAP")"
  {
    echo '#!/usr/bin/env bash'
    echo 'set -euo pipefail'
    echo "exec fpc -Fu${NEXTPAS_FPC_UNITS} ${NEXTPAS_FPC_SDK:+-XR${NEXTPAS_FPC_SDK}} \"\$@\""
  } >"$WRAP"
  chmod +x "$WRAP"
  export FPC="$WRAP"
  echo "fpc-wrap=$WRAP units=$NEXTPAS_FPC_UNITS"
fi

# Documented set (ROADMAP): D2.b platform gates + mem host-runtime (G5.x).
# Optional third field: make target (default "test"). Use host-runtime for mem
# real-OS smoke without FORCE_HOST cross-compile on Darwin.
MODULE_ENTRIES=(
  "platform.time tests/nextpas.core.platform.time/test_platform_time_helpers"
  "platform.sync tests/nextpas.core.platform.sync/test_platform_sync"
  "platform.thread tests/nextpas.core.platform.thread/test_platform_thread"
  "platform.files tests/nextpas.core.platform.files/test_platform_files"
  "platform.path tests/nextpas.core.platform.path/test_platform_path"
  "platform.env tests/nextpas.core.platform.env/test_platform_env"
  "platform.error tests/nextpas.core.platform.error/test_platform_error"
  "platform.socket tests/nextpas.core.platform.socket/test_platform_socket"
  "platform.memory tests/nextpas.core.platform.memory/test_platform_memory"
  "platform.console tests/nextpas.core.platform.console/test_platform_console"
  "mem.host_runtime tests/nextpas.core.mem/test_mem_cross_os_compile_gate host-runtime"
)

pass_count=0
fail_count=0
failed=()
# Per-gate wall clock (seconds). Prevents a hung gate from blocking the job.
GATE_TIMEOUT_SEC="${NEXTPAS_MACOS_GATE_TIMEOUT_SEC:-180}"

echo "=== Platform macOS CI Matrix (real host) ==="
echo "truth=macos-focused-runtime; documented 9 platform gates (+ optional mem.host); platform.console=candidate (not promoted 10 until GHA green); layer A fail-closed only; not full-host macOS parity"
echo "core=$CORE_ROOT"
echo "gate_timeout_sec=$GATE_TIMEOUT_SEC"
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
  rest="${entry#* }"
  if [[ "$rest" == *" "* ]]; then
    dir="${rest% *}"
    target="${rest##* }"
  else
    dir="$rest"
    target="test"
  fi
  if [[ ! -d "$dir" ]]; then
    echo "FAIL $name : missing directory $dir"
    fail_count=$((fail_count + 1))
    failed+=("$name (missing $dir)")
    continue
  fi

  echo "=== macos: $name ($dir target=$target) ==="
  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=15 "${GATE_TIMEOUT_SEC}" \
      make -C "$dir" clean "$target"
    code=$?
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout --signal=TERM --kill-after=15 "${GATE_TIMEOUT_SEC}" \
      make -C "$dir" clean "$target"
    code=$?
  else
    # macOS often lacks GNU timeout; use perl alarm wrapper.
    perl -e 'alarm shift; exec @ARGV' "${GATE_TIMEOUT_SEC}" \
      make -C "$dir" clean "$target"
    code=$?
  fi
  set -e
  if [[ "$code" -eq 0 ]]; then
    echo "PASS $name"
    pass_count=$((pass_count + 1))
  else
    if [[ "$code" -eq 124 ]] || [[ "$code" -eq 142 ]] || [[ "$code" -eq 14 ]]; then
      echo "FAIL $name (timeout ${GATE_TIMEOUT_SEC}s, exit $code)"
      failed+=("$name (timeout ${GATE_TIMEOUT_SEC}s)")
    else
      echo "FAIL $name (exit $code)"
      failed+=("$name (exit $code)")
    fi
    fail_count=$((fail_count + 1))
  fi
  echo
done

echo "summary: pass=$pass_count fail=$fail_count total=${#MODULE_ENTRIES[@]}"
echo "truth=macos-focused-runtime; gates_passed=$pass_count; gates_failed=$fail_count; scope=platform-9+mem-host-runtime"

if [[ "$fail_count" -gt 0 ]]; then
  echo "failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
  exit 1
fi

exit 0
