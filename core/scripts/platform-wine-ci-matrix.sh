#!/bin/bash

set -euo pipefail

CORE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CORE_ROOT/.." && pwd)"

COLOR_PASS="$(printf '\033[32m')"
COLOR_FAIL="$(printf '\033[31m')"
COLOR_SKIP="$(printf '\033[33m')"
COLOR_RESET="$(printf '\033[0m')"

MODULE_ENTRIES=(
  "platform.time core/tests/nextpas.core.platform.time/test_platform_time_wine"
  "platform.memory core/tests/nextpas.core.platform.memory/test_platform_memory_wine"
  "platform.sync core/tests/nextpas.core.platform.sync/test_platform_sync_wine"
  "platform.thread core/tests/nextpas.core.platform.thread/test_platform_thread_wine"
  "platform.io core/tests/nextpas.core.platform.io/test_platform_io_wine"
  "platform.process core/tests/nextpas.core.platform.process/test_platform_process_wine"
  "platform.files core/tests/nextpas.core.platform.files/test_platform_files_wine"
  "platform.fs core/tests/nextpas.core.platform.fs/test_platform_fs_wine"
  "platform.path core/tests/nextpas.core.platform.path/test_platform_path_wine"
  "platform.env core/tests/nextpas.core.platform.env/test_platform_env_wine"
  "platform.mmap core/tests/nextpas.core.platform.mmap/test_platform_mmap_wine"
  "platform.random core/tests/nextpas.core.platform.random/test_platform_random_wine"
  "platform.socket core/tests/nextpas.core.platform.socket/test_platform_socket_wine"
  "io.reactor.iocp core/tests/nextpas.core.io.uring/test_reactor_iocp_wine"
)

pass_count=0
fail_count=0
skip_count=0
summary_rows=()
failed_logs=()

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

module_dir_for_entry() {
  local entry="$1"
  local test_dir="${entry#* }"
  printf '%s/%s' "$REPO_ROOT" "$test_dir"
}

extract_summary_line() {
  local log_path="$1"
  local summary

  summary="$(grep -E -- '--- .*: [0-9]+ total, [0-9]+ passed, [0-9]+ failed ---' "$log_path" | tail -n 1 || true)"
  if [ -n "$summary" ]; then
    trim_whitespace "$summary"
    return 0
  fi

  summary="$(grep -E -- 'truth=wine-runtime-smoke' "$log_path" | tail -n 1 || true)"
  if [ -n "$summary" ]; then
    trim_whitespace "$summary"
    return 0
  fi

  summary="$(grep -E -- 'wine-runtime-smoke requires Wine' "$log_path" | tail -n 1 || true)"
  if [ -n "$summary" ]; then
    trim_whitespace "$summary"
    return 0
  fi

  summary="$(grep -E -- 'SKIP:' "$log_path" | tail -n 1 || true)"
  if [ -n "$summary" ]; then
    trim_whitespace "$summary"
    return 0
  fi

  printf '%s' "no summary line captured"
}

append_summary_row() {
  local module_name="$1"
  local status="$2"
  local summary="$3"

  summary_rows+=("$(printf '%-18s | %-6s | %s' "$module_name" "$status" "$summary")")
}

append_failed_log() {
  local module_name="$1"
  local log_path="$2"

  failed_logs+=("$module_name: $log_path")
}

run_module() {
  local module_name="$1"
  local test_dir="$2"
  local abs_test_dir="$REPO_ROOT/$test_dir"
  local log_path
  local status
  local summary
  local exit_code

  if [ ! -d "$abs_test_dir" ]; then
    fail_count=$((fail_count + 1))
    append_summary_row "$module_name" "FAIL" "missing test directory: $abs_test_dir"
    append_failed_log "$module_name" "$abs_test_dir"
    printf '%s %s\n' "${COLOR_FAIL}FAIL${COLOR_RESET}" "$module_name: missing test directory"
    return 0
  fi

  log_path="$(mktemp "/tmp/${module_name//./_}.wine.XXXXXX.log")"
  if make -C "$abs_test_dir" wine-runtime-smoke >"$log_path" 2>&1; then
    pass_count=$((pass_count + 1))
    status="PASS"
    printf '%s %s\n' "${COLOR_PASS}PASS${COLOR_RESET}" "$module_name"
  else
    exit_code=$?
    summary="$(extract_summary_line "$log_path")"
    if [ "$exit_code" -eq 2 ]; then
      skip_count=$((skip_count + 1))
      status="SKIP"
      printf '%s %s\n' "${COLOR_SKIP}SKIP${COLOR_RESET}" "$module_name"
      if [ "$summary" = "no summary line captured" ]; then
        summary="wine-runtime-smoke requires Wine"
      fi
    else
      fail_count=$((fail_count + 1))
      status="FAIL"
      append_failed_log "$module_name" "$log_path"
      printf '%s %s\n' "${COLOR_FAIL}FAIL${COLOR_RESET}" "$module_name"
    fi
    append_summary_row "$module_name" "$status" "$summary"
    return 0
  fi

  summary="$(extract_summary_line "$log_path")"
  append_summary_row "$module_name" "$status" "$summary"
}

if ! which wine >/dev/null 2>&1; then
  echo "SKIP: Wine not available"
  exit 0
fi

echo "=== Platform Wine CI Matrix ==="

for entry in "${MODULE_ENTRIES[@]}"; do
  module_name="${entry%% *}"
  test_dir="${entry#* }"
  run_module "$module_name" "$test_dir"
done

echo
printf '%-18s | %-6s | %s\n' "Module" "Status" "Summary"
printf '%-18s-+-%-6s-+-%s\n' "------------------" "------" "----------------------------------------"
for row in "${summary_rows[@]}"; do
  printf '%s\n' "$row"
done

echo
echo "summary: pass=$pass_count fail=$fail_count skip=$skip_count total=${#MODULE_ENTRIES[@]}"

if [ "${#failed_logs[@]}" -gt 0 ]; then
  echo "failed logs:"
  for failed_log in "${failed_logs[@]}"; do
    printf '%s\n' "$failed_log"
  done
fi

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
