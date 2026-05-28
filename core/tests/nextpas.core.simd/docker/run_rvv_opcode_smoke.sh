#!/usr/bin/env bash
set -euo pipefail

# Run from repo root inside container
if [[ ! -d tests/nextpas.core.simd ]]; then
  echo "[ERROR] Expected repo root with tests/nextpas.core.simd/"
  exit 2
fi

cd tests/nextpas.core.simd

TARGET_CPU="$(fpc -iTP)"
TARGET_OS="$(fpc -iTO)"
TARGET="${TARGET_CPU}-${TARGET_OS}"

BIN_DIR="bin2-smoke"
UNIT_DIR="lib2-smoke/${TARGET}"
LOG_DIR="logs"

SMOKE_SOURCE="${LOG_DIR}/rvv_opcode_smoke.pas"
BUILD_LOG="${LOG_DIR}/rvv_opcode_smoke_build_${TARGET}.txt"
ASM_FILE="${UNIT_DIR}/rvv_opcode_smoke.s"
OBJ_FILE="${UNIT_DIR}/rvv_opcode_smoke.o"
AS_BIN="${SIMD_RVV_OPCODE_AS_BIN:-riscv64-linux-gnu-as}"
AS_ARCH="${SIMD_RVV_OPCODE_AS_ARCH:-rv64gcv}"
AS_MABI="${SIMD_RVV_OPCODE_AS_MABI:-lp64d}"
FPC_EXTRA_DEFINES_STRING="${SIMD_FPC_EXTRA_DEFINES:-}"
FPC_EXTRA_ARGS_STRING="${SIMD_FPC_EXTRA_ARGS:-}"
FPC_EXTRA_DEFINES=()
FPC_EXTRA_ARGS=()

if [[ -n "${FPC_EXTRA_DEFINES_STRING}" ]]; then
  read -r -a FPC_EXTRA_DEFINES <<< "${FPC_EXTRA_DEFINES_STRING}"
fi
if [[ -n "${FPC_EXTRA_ARGS_STRING}" ]]; then
  read -r -a FPC_EXTRA_ARGS <<< "${FPC_EXTRA_ARGS_STRING}"
fi
if ! command -v "${AS_BIN}" >/dev/null 2>&1; then
  echo "[RVV-SMOKE] missing assembler: ${AS_BIN}"
  exit 2
fi

mkdir -p "${BIN_DIR}" "${UNIT_DIR}" "${LOG_DIR}"

cat > "${SMOKE_SOURCE}" <<'EOF'
program rvv_opcode_smoke;
{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}

procedure RVVOpcodeProbe(const a, b: Pointer); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfadd.vv v0, v0, v1
  vse32.v v0, (a0)
end;

begin
end.
EOF

echo "[RVV-SMOKE] version=$(fpc -iV) target=${TARGET}"
if [[ -n "${FPC_EXTRA_DEFINES_STRING}" ]]; then
  echo "[RVV-SMOKE] extra-defines=${FPC_EXTRA_DEFINES_STRING}"
fi
if [[ -n "${FPC_EXTRA_ARGS_STRING}" ]]; then
  echo "[RVV-SMOKE] extra-args=${FPC_EXTRA_ARGS_STRING}"
fi

: > "${BUILD_LOG}"
if fpc -B -Mobjfpc -Sc -Si -O1 -g -gl -a -s \
  -Fu../../src -Fi../../src \
  -FE"${BIN_DIR}" -FU"${UNIT_DIR}" \
  "${FPC_EXTRA_DEFINES[@]}" \
  "${FPC_EXTRA_ARGS[@]}" \
  "${SMOKE_SOURCE}" > "${BUILD_LOG}" 2>&1; then
  echo "[RVV-SMOKE] fpc-phase OK"
else
  rc=$?
  echo "[RVV-SMOKE] FAILED rc=${rc} (see ${BUILD_LOG})"
  tail -n 120 "${BUILD_LOG}" || true
  exit "${rc}"
fi

if [[ ! -f "${ASM_FILE}" ]]; then
  echo "[RVV-SMOKE] missing asm output: ${ASM_FILE}"
  exit 2
fi

if "${AS_BIN}" -o "${OBJ_FILE}" -march="${AS_ARCH}" -mabi="${AS_MABI}" "${ASM_FILE}" >> "${BUILD_LOG}" 2>&1; then
  echo "[RVV-SMOKE] as-phase OK"
  echo "[RVV-SMOKE] asm-file=${ASM_FILE}"
  echo "[RVV-SMOKE] obj-file=${OBJ_FILE}"
  echo "[RVV-SMOKE] build-log=${BUILD_LOG}"
else
  rc=$?
  echo "[RVV-SMOKE] FAILED at as-phase rc=${rc} (see ${BUILD_LOG})"
  tail -n 120 "${BUILD_LOG}" || true
  exit "${rc}"
fi
