#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST_ROOT="${SIMD_NONX86_NATIVE_EVIDENCE_IMPORT_DEST:-${ROOT}/fixtures/native-evidence}"
VERIFY_SCRIPT="${ROOT}/verify_nonx86_native_evidence.py"
REQUESTED_BACKEND="all"
SYNTHETIC_OUTPUT_ROOT_MARKER="/tmp/simd-import-smoke"

print_usage() {
  cat <<'EOF'
Usage: import_nonx86_native_evidence_artifacts.sh [--backend neon|riscvv|all] <source-dir> [source-dir...]

Import externally collected native non-x86 evidence directories into:
- tests/nextpas.core.simd/fixtures/native-evidence

Each <source-dir> may be:
- a directory that directly matches native-evidence-neon-*
- a directory that directly matches native-evidence-riscvv-*
- a parent directory containing one or more native-evidence-neon-*/native-evidence-riscvv-* directories
- an already imported directory under tests/nextpas.core.simd/fixtures/native-evidence (import becomes a verify-only no-op)

After import, the script runs verify_nonx86_native_evidence.py against the destination root.
EOF
}

require_dir() {
  local aDir

  aDir="${1:-}"
  if [[ -z "${aDir}" ]]; then
    echo "[IMPORT] Missing source directory"
    print_usage
    exit 2
  fi
  if [[ ! -d "${aDir}" ]]; then
    echo "[IMPORT] Missing source directory: ${aDir}"
    exit 2
  fi
}

resolve_dir_path() {
  local aDir

  aDir="${1:-}"
  require_dir "${aDir}"
  (
    cd "${aDir}"
    pwd -P
  )
}

paths_equal() {
  local aLeft
  local aRight

  aLeft="${1:-}"
  aRight="${2:-}"
  if [[ -z "${aLeft}" || -z "${aRight}" ]]; then
    return 1
  fi

  [[ "$(resolve_dir_path "${aLeft}")" == "$(resolve_dir_path "${aRight}")" ]]
}

resolve_latest_backend_dir() {
  local aBackend
  local aSource
  local LSource
  local LBaseName
  local LCandidate
  local -a LMatches

  aBackend="${1:-}"
  shift || true
  LMatches=()

  for aSource in "$@"; do
    require_dir "${aSource}"
    LSource="$(cd "${aSource}" && pwd)"
    LBaseName="$(basename "${LSource}")"
    if [[ "${LBaseName}" == native-evidence-${aBackend}-* ]]; then
      LMatches+=("${LSource}")
      continue
    fi

    while IFS= read -r -d '' LCandidate; do
      LMatches+=("${LCandidate}")
    done < <(find "${LSource}" -type d -name "native-evidence-${aBackend}-*" -print0 | sort -z)
  done

  if [[ "${#LMatches[@]}" -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${LMatches[@]}" | sort | tail -n 1
}

verify_source_dir_integrity() {
  local aBackend
  local aSourceDir
  local LResolvedSource
  local LSummary
  local LHeader
  local LStamp
  local LDirStamp

  aBackend="${1:-}"
  aSourceDir="${2:-}"
  LResolvedSource="$(resolve_dir_path "${aSourceDir}")"
  LSummary="${LResolvedSource}/summary.md"
  LDirStamp="$(basename "${LResolvedSource}")"
  LDirStamp="${LDirStamp#native-evidence-${aBackend}-}"

  if [[ ! -f "${LSummary}" ]]; then
    echo "[IMPORT] Missing summary.md in ${LResolvedSource}"
    exit 1
  fi

  LHeader="$(sed -n '1p' "${LSummary}")"
  if [[ ! "${LHeader}" =~ ^#\ SIMD\ Non-X86\ Native\ Evidence\ \(([0-9]{8}-[0-9]{6})\)$ ]]; then
    echo "[IMPORT] Invalid summary header in ${LSummary}: ${LHeader}"
    exit 1
  fi
  LStamp="${BASH_REMATCH[1]}"

  if [[ "${LStamp}" != "${LDirStamp}" ]]; then
    echo "[IMPORT] Synthetic or repackaged evidence detected: summary stamp ${LStamp} does not match directory stamp ${LDirStamp} (${LResolvedSource})"
    exit 1
  fi

  if grep -F -- "${SYNTHETIC_OUTPUT_ROOT_MARKER}" "${LSummary}" >/dev/null; then
    echo "[IMPORT] Synthetic import-smoke evidence is not allowed: ${LSummary}"
    exit 1
  fi
}

purge_backend_dirs() {
  local aBackend
  local LExisting

  aBackend="${1:-}"
  mkdir -p "${DEST_ROOT}"

  while IFS= read -r -d '' LExisting; do
    rm -rf "${LExisting}"
    echo "[IMPORT] remove: ${LExisting}"
  done < <(find "${DEST_ROOT}" -maxdepth 1 -mindepth 1 -type d -name "native-evidence-${aBackend}-*" -print0 | sort -z)
}

copy_backend_dir() {
  local aBackend
  local aSourceDir
  local LResolvedSource
  local LTargetDir

  aBackend="${1:-}"
  aSourceDir="${2:-}"
  LResolvedSource="$(resolve_dir_path "${aSourceDir}")"
  LTargetDir="${DEST_ROOT}/$(basename "${LResolvedSource}")"

  if [[ ! -f "${LResolvedSource}/summary.md" ]]; then
    echo "[IMPORT] Missing summary.md in ${LResolvedSource}"
    exit 1
  fi
  if [[ ! -f "${LResolvedSource}/environment.txt" ]]; then
    echo "[IMPORT] Missing environment.txt in ${LResolvedSource}"
    exit 1
  fi

  verify_source_dir_integrity "${aBackend}" "${LResolvedSource}"

  if [[ -d "${LTargetDir}" ]] && paths_equal "${LResolvedSource}" "${LTargetDir}"; then
    echo "[IMPORT] keep: ${LResolvedSource} already lives under ${DEST_ROOT}"
    return 0
  fi

  purge_backend_dirs "${aBackend}"
  cp -a "${LResolvedSource}" "${DEST_ROOT}/"
  echo "[IMPORT] copy: ${LResolvedSource} -> ${DEST_ROOT}/$(basename "${LResolvedSource}")"
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    --backend)
      shift || true
      REQUESTED_BACKEND="${1:-}"
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    --*)
      echo "[IMPORT] Unknown option: ${1}"
      print_usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
  shift || true
done

if [[ "$#" -lt 1 ]]; then
  print_usage
  exit 2
fi

case "${REQUESTED_BACKEND}" in
  all|neon|riscvv)
    ;;
  *)
    echo "[IMPORT] Unsupported backend: ${REQUESTED_BACKEND}"
    print_usage
    exit 2
    ;;
esac

mkdir -p "${DEST_ROOT}"
DEST_ROOT="$(cd "${DEST_ROOT}" && pwd -P)"

if [[ "${REQUESTED_BACKEND}" == "all" || "${REQUESTED_BACKEND}" == "neon" ]]; then
  LNeonSource="$(resolve_latest_backend_dir neon "$@")" || {
    echo "[IMPORT] Missing native-evidence-neon-* under: $*"
    exit 1
  }
  copy_backend_dir neon "${LNeonSource}"
fi

if [[ "${REQUESTED_BACKEND}" == "all" || "${REQUESTED_BACKEND}" == "riscvv" ]]; then
  LRiscvvSource="$(resolve_latest_backend_dir riscvv "$@")" || {
    echo "[IMPORT] Missing native-evidence-riscvv-* under: $*"
    exit 1
  }
  copy_backend_dir riscvv "${LRiscvvSource}"
fi

if [[ ! -f "${VERIFY_SCRIPT}" ]]; then
  echo "[IMPORT] Missing verifier: ${VERIFY_SCRIPT}"
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "[IMPORT] FAILED (python3 runtime not found; verify_nonx86_native_evidence.py is required after import)"
  exit 2
fi

echo "[IMPORT] verify: python3 ${VERIFY_SCRIPT} --root ${DEST_ROOT} --backend ${REQUESTED_BACKEND} --summary-line"
python3 "${VERIFY_SCRIPT}" --root "${DEST_ROOT}" --backend "${REQUESTED_BACKEND}" --summary-line
echo "[IMPORT] OK dest=${DEST_ROOT} backend=${REQUESTED_BACKEND}"
