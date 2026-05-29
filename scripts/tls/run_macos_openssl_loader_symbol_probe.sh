#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_ID=""
OUTPUT_REL=""
BIN_DIR_REL=""
UNIT_DIR_REL=""
OPENSSL_ROOT_OVERRIDE=""
FPC_EXE="${FAFAFA_FPC_EXE:-fpc}"

usage() {
  cat <<'EOF'
Usage: scripts/run_macos_openssl_loader_symbol_probe.sh [options]

Options:
  --run-id ID         Optional run id for default output paths
  --output FILE       Output JSON path (relative to project root or absolute)
  --bin-dir DIR       Binary output directory (relative to project root or absolute)
  --unit-dir DIR      FPC unit output directory (relative to project root or absolute)
  --openssl-root DIR  Optional OpenSSL root override
  --fpc-exe PATH      Optional FPC executable override
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --output)
      OUTPUT_REL="$2"
      shift 2
      ;;
    --bin-dir)
      BIN_DIR_REL="$2"
      shift 2
      ;;
    --unit-dir)
      UNIT_DIR_REL="$2"
      shift 2
      ;;
    --openssl-root)
      OPENSSL_ROOT_OVERRIDE="$2"
      shift 2
      ;;
    --fpc-exe)
      FPC_EXE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(date +%Y%m%d_%H%M%S)"
fi

resolve_path() {
  local value="$1"
  if [[ "$value" = /* ]]; then
    printf '%s\n' "$value"
  else
    printf '%s/%s\n' "$PROJECT_ROOT" "$value"
  fi
}

if [[ -n "$OPENSSL_ROOT_OVERRIDE" ]]; then
  export OPENSSL_ROOT="$OPENSSL_ROOT_OVERRIDE"
fi

if [[ -z "$OUTPUT_REL" ]]; then
  OUTPUT_REL="test-reports/wave_b_macos_loader_symbol_probe_${RUN_ID}.json"
fi
if [[ -z "$BIN_DIR_REL" ]]; then
  BIN_DIR_REL="tmp/wave_b_macos_loader_symbol_probe_bin_${RUN_ID}"
fi
if [[ -z "$UNIT_DIR_REL" ]]; then
  UNIT_DIR_REL="tmp/wave_b_macos_loader_symbol_probe_units_${RUN_ID}"
fi

OUTPUT_ABS="$(resolve_path "$OUTPUT_REL")"
BIN_DIR_ABS="$(resolve_path "$BIN_DIR_REL")"
UNIT_DIR_ABS="$(resolve_path "$UNIT_DIR_REL")"
PROGRAM_PATH="tests/diagnostic/test_macos_openssl_loader_symbol_probe.pas"
PROGRAM_BASENAME="test_macos_openssl_loader_symbol_probe"
PROGRAM_ABS="$BIN_DIR_ABS/$PROGRAM_BASENAME"

mkdir -p "$(dirname "$OUTPUT_ABS")" "$BIN_DIR_ABS" "$UNIT_DIR_ABS"

compile_words=(
  "$FPC_EXE"
  -Fu./src
  -Fu./tests
  -Fu./tests/framework
  -FU"$UNIT_DIR_ABS"
  -FE"$BIN_DIR_ABS"
  -o"$PROGRAM_ABS"
)

if [[ -n "${OPENSSL_ROOT:-}" ]]; then
  compile_words+=(
    -Fl"${OPENSSL_ROOT}/lib"
    -Fi"${OPENSSL_ROOT}/include"
    -k-rpath
    -k"${OPENSSL_ROOT}/lib"
  )
fi

compile_words+=("$PROGRAM_PATH")

echo "[MACOS-LOADER-PROBE] compile: ${compile_words[*]}"
(
  cd "$PROJECT_ROOT"
  "${compile_words[@]}"
)

echo "[MACOS-LOADER-PROBE] run: $PROGRAM_ABS $OUTPUT_ABS"
(
  cd "$PROJECT_ROOT"
  "$PROGRAM_ABS" "$OUTPUT_ABS"
)

if [[ ! -f "$OUTPUT_ABS" ]]; then
  echo "[FAIL] expected probe output: $OUTPUT_ABS" >&2
  exit 1
fi

echo "[MACOS-LOADER-PROBE] output: $OUTPUT_ABS"
