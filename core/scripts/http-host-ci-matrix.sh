#!/usr/bin/env bash
# http-host-ci-matrix.sh
#
# Multi-OS host CI smoke for HTTP threaded cleartext path + IOCP wire
# + product facade over IOCP.
# Runs on real Linux / macOS / Windows / FreeBSD CI hosts (not Wine).
#
# Usage (cwd = core/ or repo root):
#   ./scripts/http-host-ci-matrix.sh
#   ./core/scripts/http-host-ci-matrix.sh
#
# Evidence: truth=host-runtime for the documented HTTP gate set only.
# IOCP wire + facade smokes run their real cases on Windows hosts only;
# other hosts assert the tsbIocp factory is absent (skip branch of the
# same suites). NOT Windows scale-ready, NOT TLS-over-Windows evidence.

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

# Optional GHA macOS toolchain hints (same pattern as platform-macos-ci-matrix).
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

MODULE_ENTRIES=(
  "http.threaded_host tests/nextpas.core.http/test_http_threaded_host"
  "http.iocp_wire tests/nextpas.core.http/test_http_iocp_wine"
  "http.iocp_facade tests/nextpas.core.http/test_http_iocp_facade_wine"
)

pass_count=0
fail_count=0
failed=()

HOST_LABEL="${CORE_CI_HOST:-$(uname -s 2>/dev/null || echo unknown)}"

echo "=== HTTP host CI Matrix (real host) ==="
echo "truth=host-runtime; host=$HOST_LABEL; NOT scale-ready; NOT TLS-over-Windows; IOCP wire+facade real cases on Windows hosts only"
echo "core=$CORE_ROOT"
echo "fpc=$(command -v fpc 2>/dev/null || true)"
if [[ -n "${FPC:-}" ]]; then
  echo "FPC=$FPC"
  "$FPC" -iV 2>/dev/null || true
  "$FPC" -iTP -iTO 2>/dev/null || true
else
  fpc -iV 2>/dev/null || true
  fpc -iTP -iTO 2>/dev/null || true
fi
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

  echo "=== http-host: $name ($dir target=$target) ==="
  if make -C "$dir" clean "$target"; then
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
echo "truth=host-runtime; host=$HOST_LABEL; gates_passed=$pass_count; gates_failed=$fail_count"

if [[ "$fail_count" -gt 0 ]]; then
  echo "failed:"
  for item in "${failed[@]}"; do
    printf '  - %s\n' "$item"
  done
  exit 1
fi

exit 0