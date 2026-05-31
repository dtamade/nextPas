#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
FAST_LOCAL=false
RUN_ID="${FAFAFA_FREEPASCAL_TLS13_COMPLETENESS_RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
REPORTS_DIR="${FAFAFA_FREEPASCAL_TLS13_COMPLETENESS_REPORTS_DIR:-test-reports}"
FPC_EXE="${FAFAFA_FPC_EXE:-fpc}"

usage() {
  cat <<'USAGE'
FreePascal TLS 1.3 completeness gate

Usage:
  scripts/run_freepascal_tls13_completeness_gate.sh [options]

Options:
  --dry-run              Print commands without executing them
  --fast-local           Write reports under ./tmp/test-reports
  --run-id ID            Override run id
  --reports-dir DIR      Relative reports directory (default: test-reports)
  --fpc-exe PATH         Override FPC executable
  -h, --help             Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --fast-local)
      FAST_LOCAL=true
      shift
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --reports-dir)
      REPORTS_DIR="$2"
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
      echo "[FAIL] unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$REPORTS_DIR" = /* ]]; then
  echo "[FAIL] --reports-dir must be relative to repo root: $REPORTS_DIR" >&2
  exit 2
fi

if [[ "$FAST_LOCAL" == "true" && "$REPORTS_DIR" == "test-reports" ]]; then
  REPORTS_DIR="tmp/test-reports"
fi

WORK_ROOT="tmp/freepascal_tls13_completeness_${RUN_ID}"
SUMMARY_FILE="$PROJECT_ROOT/$REPORTS_DIR/freepascal_tls13_completeness_${RUN_ID}.md"

TEST_NAMES=(
  "test_tls13_posthandshake"
  "test_tls13_resumption"
  "test_rfc8448_psk_binder"
  "test_tls13_clienthello_parser"
  "test_tls13_servercertverify"
  "test_freepascal_revocation_fast_contracts"
  "test_freepascal_client_certificateverify_runtime"
  "test_freepascal_client_chain_trust_runtime"
  "test_freepascal_client_ocsp_stapling_runtime"
  "test_freepascal_server_ocsp_stapling_runtime"
  "test_freepascal_client_online_ocsp_runtime"
  "test_freepascal_client_ct_sct_surface"
  "test_freepascal_client_cert_verify_flags_runtime"
  "test_freepascal_client_session_resumption"
  "test_freepascal_server_session_resumption"
  "test_freepascal_tls13_early_data"
  "test_freepascal_backend_basic"
  "test_capability_cache"
)

TEST_FILES=(
  "tests/test_tls13_posthandshake.pas"
  "tests/test_tls13_resumption.pas"
  "tests/test_rfc8448_psk_binder.pas"
  "tests/test_tls13_clienthello_parser.pas"
  "tests/test_tls13_servercertverify.pas"
  "tests/test_freepascal_revocation_fast_contracts.pas"
  "tests/test_freepascal_client_certificateverify_runtime.pas"
  "tests/test_freepascal_client_chain_trust_runtime.pas"
  "tests/test_freepascal_client_ocsp_stapling_runtime.pas"
  "tests/test_freepascal_server_ocsp_stapling_runtime.pas"
  "tests/test_freepascal_client_online_ocsp_runtime.pas"
  "tests/test_freepascal_client_ct_sct_surface.pas"
  "tests/test_freepascal_client_cert_verify_flags_runtime.pas"
  "tests/test_freepascal_client_session_resumption.pas"
  "tests/test_freepascal_server_session_resumption.pas"
  "tests/test_freepascal_tls13_early_data.pas"
  "tests/test_freepascal_backend_basic.pas"
  "tests/test_capability_cache.pas"
)

shell_join() {
  local parts=()
  local part
  for part in "$@"; do
    parts+=("$(printf '%q' "$part")")
  done
  local IFS=' '
  echo "${parts[*]}"
}

run_test_case() {
  local name="$1"
  local file="$2"
  local units_dir="$WORK_ROOT/${name}.units"
  local bin_dir="$WORK_ROOT/${name}.bin"
  local exe_path="$bin_dir/$name"
  local compile_cmd_words=(
    "$FPC_EXE"
    -B
    -Fu./src
    -Fu./tests
    -Fu./tests/framework
    "-FU$units_dir"
    "-FE$bin_dir"
    "-o$exe_path"
    "$file"
  )
  local run_cmd_words=(
    "$exe_path"
  )
  local display_cmd
  display_cmd="mkdir -p $(shell_join "$units_dir" "$bin_dir") && $(shell_join "${compile_cmd_words[@]}") && $(shell_join "${run_cmd_words[@]}")"

  echo "[GATE] $display_cmd"

  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi

  mkdir -p "$PROJECT_ROOT/$units_dir" "$PROJECT_ROOT/$bin_dir"

  set +e
  (
    cd "$PROJECT_ROOT"
    "${compile_cmd_words[@]}"
  )
  local compile_ec=$?
  local run_ec=0
  if [[ "$compile_ec" == "0" ]]; then
    (
      cd "$PROJECT_ROOT"
      "${run_cmd_words[@]}"
    )
    run_ec=$?
  fi
  set -e

  if [[ "$compile_ec" != "0" ]]; then
    return "$compile_ec"
  fi

  return "$run_ec"
}

mkdir -p "$PROJECT_ROOT/$REPORTS_DIR"

echo "========================================"
echo "FreePascal TLS 1.3 Completeness Gate"
echo "========================================"
echo "[INFO] run_id: $RUN_ID"
echo "[INFO] reports_dir: $PROJECT_ROOT/$REPORTS_DIR"
echo "[INFO] work_root: $PROJECT_ROOT/$WORK_ROOT"
echo "[INFO] summary_file: $SUMMARY_FILE"
echo "[INFO] fpc_exe: $FPC_EXE"

if [[ "$DRY_RUN" == "true" ]]; then
  for idx in "${!TEST_NAMES[@]}"; do
    name="${TEST_NAMES[$idx]}"
    file="${TEST_FILES[$idx]}"
    run_test_case "$name" "$file"
  done
  echo "[PASS] dry-run complete"
  exit 0
fi

pass_count=0
fail_count=0

{
  echo "# FreePascal TLS 1.3 Completeness Gate"
  echo
  echo "- run_id: \`$RUN_ID\`"
  echo "- work_root: \`$WORK_ROOT\`"
  echo
  echo "| test | status |"
  echo "|---|---|"
} > "$SUMMARY_FILE"

for idx in "${!TEST_NAMES[@]}"; do
  name="${TEST_NAMES[$idx]}"
  file="${TEST_FILES[$idx]}"

  if run_test_case "$name" "$file"; then
    echo "| \`$name\` | PASS |" >> "$SUMMARY_FILE"
    pass_count=$((pass_count + 1))
  else
    echo "| \`$name\` | FAIL |" >> "$SUMMARY_FILE"
    fail_count=$((fail_count + 1))
  fi
done

{
  echo
  echo "- passed: $pass_count"
  echo "- failed: $fail_count"
} >> "$SUMMARY_FILE"

if [[ "$fail_count" -ne 0 ]]; then
  echo "[FAIL] freepascal tls13 completeness gate failed ($fail_count failing test group(s))"
  exit 1
fi

echo "[PASS] freepascal tls13 completeness gate finished"
