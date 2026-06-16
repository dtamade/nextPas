#!/usr/bin/env bash
# platform-cross-ci-matrix.sh — cross-compile CI matrix for Tier 2 targets
#
# Evidence tier: forced-compile
# Targets: riscv64, aarch64, arm32 (all Linux)
#
# Each target builds a smoke program that uses all 13 platform facade
# modules via forced cross-compile. Runtime smoke is skipped in this
# gate; the script only verifies source-level cross-compilation
# coherence across architectures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${CORE_ROOT}/.." && pwd)"
BUILD_ROOT="${CORE_ROOT}/build/cross-ci-matrix"

# ── color helpers ──────────────────────────────────────────────────
COLOR_PASS=$'\033[32m'
COLOR_FAIL=$'\033[31m'
COLOR_SKIP=$'\033[33m'
COLOR_RESET=$'\033[0m'

# ── target matrix ──────────────────────────────────────────────────
# Each entry: "label  test-dir-relative-to-core/tests"
# Modules exercised: platform.time, platform.memory, platform.sync,
#   platform.thread, platform.io, platform.process, platform.files,
#   platform.fs, platform.path, platform.env, platform.mmap,
#   platform.random, platform.socket
declare -a TARGETS=(
  "riscv64-linux  nextpas.core.platform/test_platform_linux_riscv64_compile"
  "aarch64-linux  nextpas.core.platform/test_platform_linux_aarch64_compile"
  "arm32-linux    nextpas.core.platform/test_platform_linux_arm32_compile"
)

# ── state ───────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAIL_LOG_PATHS=()
mkdir -p "${BUILD_ROOT}"
TMPDIR="$(mktemp -d "${BUILD_ROOT}/tmp.XXXXXX")"

# ── helpers ─────────────────────────────────────────────────────────
log_pass() { printf "  ${COLOR_PASS}PASS${COLOR_RESET}  %s\n" "$1"; }
log_fail() { printf "  ${COLOR_FAIL}FAIL${COLOR_RESET}  %s  %s\n" "$1" "$2"; }
log_skip() { printf "  ${COLOR_SKIP}SKIP${COLOR_RESET}  %s  %s\n" "$1" "$2"; }

# ── main ────────────────────────────────────────────────────────────
main() {
  echo ""
  echo "=== platform cross CI matrix ==="
  echo ""

  for target_entry in "${TARGETS[@]}"; do
    read -r label test_dir <<<"${target_entry}"
    local full_dir="${REPO_ROOT}/core/tests/${test_dir}"
    local log_path="${TMPDIR}/${label//\//_}.log"

    if [[ ! -d "${full_dir}" ]]; then
      log_skip "${label}" "test directory not found: ${test_dir}"
      ((SKIP_COUNT++)) || true
      continue
    fi

    if [[ ! -f "${full_dir}/Makefile" ]]; then
      log_skip "${label}" "no Makefile in ${test_dir}"
      ((SKIP_COUNT++)) || true
      continue
    fi

    echo "--- ${label} ---"

    if make -C "${full_dir}" build \
      >"${log_path}" 2>&1; then
      log_pass "${label}"
      ((PASS_COUNT++)) || true
    else
      log_fail "${label}" "compile failed"
      FAIL_LOG_PATHS+=("${log_path}")
      ((FAIL_COUNT++)) || true
    fi
    echo ""
  done

  # ── summary ──────────────────────────────────────────────────────
  local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
  echo "=== summary ==="
  printf "  %-10s %-10s %-40s\n" "module" "status" "target"
  for target_entry in "${TARGETS[@]}"; do
    read -r label test_dir <<<"${target_entry}"
    printf "  %-10s %-10s %-40s\n" \
      "platform" "forced-compile" "${label}"
  done
  echo ""
  echo "  pass_count : ${PASS_COUNT}"
  echo "  fail_count : ${FAIL_COUNT}"
  echo "  skip_count : ${SKIP_COUNT}"
  echo "  evidence   : forced-compile"
  echo ""

  if [[ ${#FAIL_LOG_PATHS[@]} -gt 0 ]]; then
    echo "=== failed logs ==="
    for log in "${FAIL_LOG_PATHS[@]}"; do
      echo "  log_path : ${log}"
    done
    echo ""
    exit 1
  fi
}

main "$@"
