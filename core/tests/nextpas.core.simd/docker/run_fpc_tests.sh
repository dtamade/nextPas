#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: run_fpc_tests.sh [clean|test] [runner-args...]

Examples:
  bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --list-suites
  bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_DispatchAPI
  SIMD_RUN_ONLY_BUILD=1 SIMD_FPC_EXTRA_DEFINES='-dFOO' bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --suite=TTestCase_PublicAbi
EOF
}

if [[ $# -eq 0 ]]; then
  exec bash "${ROOT}/BuildOrTest.sh" test
fi

case "${1}" in
  clean)
    shift
    exec bash "${ROOT}/BuildOrTest.sh" clean "$@"
    ;;
  test)
    shift
    exec bash "${ROOT}/BuildOrTest.sh" test "$@"
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  --vector-asm|--no-vector-asm|--list-suites|--suite=*|--suite|--no-bench|--bench|--bench-only|--pause)
    exec bash "${ROOT}/BuildOrTest.sh" test "$@"
    ;;
  *)
    echo "Unsupported action: $1"
    usage
    exit 2
    ;;
esac
