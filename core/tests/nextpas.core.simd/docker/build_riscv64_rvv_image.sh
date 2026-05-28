#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
DOCKER_DIR="${ROOT_DIR}/tests/nextpas.core.simd/docker"
DOCKERFILE_PATH="${DOCKER_DIR}/Dockerfile.riscv64-rvv"
IMAGE_BASE="${SIMD_QEMU_RVV_IMAGE_BASE:-fafafa-core-simd-test-rvv}"
IMAGE_TAG="${IMAGE_BASE}:riscv64"
DOCKER_BUILD_NETWORK="${DOCKER_BUILD_NETWORK:-default}"
RETRIES="${SIMD_QEMU_RETRIES:-3}"
PATCH_REL="${SIMD_RVV_PATCH_REL:-docs/fpc_rvv_support.patch}"
FPC_SOURCE_ARCHIVE_URL="${SIMD_RVV_FPC_SOURCE_ARCHIVE_URL:-https://gitlab.com/freepascal.org/fpc/source/-/archive/main/source-main.tar.gz}"
FPC_SOURCE_ARCHIVE_TOPDIR="${SIMD_RVV_FPC_SOURCE_ARCHIVE_TOPDIR:-source-main}"
BASE_IMAGE="${SIMD_RVV_BASE_IMAGE:-fafafa-core-simd-test:riscv64}"
FPC_MAKE_TARGET="${SIMD_RVV_FPC_MAKE_TARGET:-compiler}"
FPC_MAKE_JOBS="${SIMD_RVV_FPC_MAKE_JOBS:-1}"
FPC_ERROR_LANG="${SIMD_RVV_FPC_ERROR_LANG:-n}"

run_with_retry() {
  local aMax
  local aDesc
  local LAttempt
  local LRC

  aMax="${1}"
  shift
  aDesc="${1}"
  shift
  LAttempt=1

  while true; do
    set +e
    "$@"
    LRC=$?
    set -e

    if (( LRC == 0 )); then
      return 0
    fi
    if (( LAttempt >= aMax )); then
      echo "[RVV-IMAGE] ERROR: ${aDesc} failed after ${LAttempt} attempt(s), rc=${LRC}"
      return "${LRC}"
    fi
    echo "[RVV-IMAGE] WARN: ${aDesc} failed rc=${LRC}, retry ${LAttempt}/${aMax} ..."
    sleep $((LAttempt * 3))
    LAttempt=$((LAttempt + 1))
  done
}

if [[ ! -f "${DOCKERFILE_PATH}" ]]; then
  echo "[RVV-IMAGE] Missing Dockerfile: ${DOCKERFILE_PATH}"
  exit 2
fi

if [[ ! -f "${ROOT_DIR}/${PATCH_REL}" ]]; then
  echo "[RVV-IMAGE] Missing patch file: ${ROOT_DIR}/${PATCH_REL}"
  exit 2
fi

echo "[RVV-IMAGE] Repo: ${ROOT_DIR}"
echo "[RVV-IMAGE] Dockerfile: ${DOCKERFILE_PATH}"
echo "[RVV-IMAGE] Patch: ${PATCH_REL}"
echo "[RVV-IMAGE] Image tag: ${IMAGE_TAG}"
echo "[RVV-IMAGE] Base image: ${BASE_IMAGE}"
echo "[RVV-IMAGE] Build network: ${DOCKER_BUILD_NETWORK}"
echo "[RVV-IMAGE] Make target: ${FPC_MAKE_TARGET}"
echo "[RVV-IMAGE] Make jobs: ${FPC_MAKE_JOBS}"
echo "[RVV-IMAGE] Error lang: ${FPC_ERROR_LANG}"

if ! docker image inspect "${BASE_IMAGE}" >/dev/null 2>&1; then
  echo "[RVV-IMAGE] Missing local base image: ${BASE_IMAGE}"
  echo "[RVV-IMAGE] Hint: run qemu evidence once to materialize ${BASE_IMAGE}, or set SIMD_RVV_BASE_IMAGE."
  exit 2
fi

run_with_retry "${RETRIES}" "docker build ${IMAGE_TAG}" \
  docker buildx build \
    --platform linux/riscv64 \
    --network "${DOCKER_BUILD_NETWORK}" \
    --build-arg "RVV_BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "FPC_RVV_PATCH_REL=${PATCH_REL}" \
    --build-arg "FPC_SOURCE_ARCHIVE_URL=${FPC_SOURCE_ARCHIVE_URL}" \
    --build-arg "FPC_SOURCE_ARCHIVE_TOPDIR=${FPC_SOURCE_ARCHIVE_TOPDIR}" \
    --build-arg "FPC_MAKE_TARGET=${FPC_MAKE_TARGET}" \
    --build-arg "FPC_MAKE_JOBS=${FPC_MAKE_JOBS}" \
    --build-arg "FPC_ERROR_LANG=${FPC_ERROR_LANG}" \
    --tag "${IMAGE_TAG}" \
    --file "${DOCKERFILE_PATH}" \
    --load \
    "${ROOT_DIR}"

docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1
echo "[RVV-IMAGE] OK image=${IMAGE_TAG}"
