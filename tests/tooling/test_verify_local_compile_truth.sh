#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
VERIFY_LOCAL="$REPO_ROOT/build/verify_local.sh"
SIMULATED_HOST_MATRIX_MAKEFILE="$REPO_ROOT/core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix/Makefile"

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"

  if ! grep -Eq "$pattern" "$file"; then
    printf 'missing verify_local compile truth: %s\n' "$description" >&2
    exit 1
  fi
}

require_pattern "$VERIFY_LOCAL" 'core-platform-simulated-host-compile-matrix-check=running' 'simulated host compile matrix running marker'
require_pattern "$VERIFY_LOCAL" 'simulated-host-compile-truth=forced-compile' 'verify_local consumes forced compile truth marker'
require_pattern "$VERIFY_LOCAL" '"corePlatformSimulatedHostCompileMatrixCheck":"pass"' 'verify envelope simulated host compile matrix result'
require_pattern "$SIMULATED_HOST_MATRIX_MAKEFILE" 'simulated-host-compile-truth=forced-compile' 'simulated host compile matrix emits forced compile truth marker'

printf 'verify-local-compile-truth=pass\n'
