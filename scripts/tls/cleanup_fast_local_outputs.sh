#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_ROOT="$PROJECT_ROOT/tmp"
OLDER_THAN_DAYS="30"
ALL=false
DRY_RUN=true
VERBOSE=false

usage() {
  cat <<'USAGE'
Fast-local outputs cleanup helper

Safety defaults:
  - default is dry-run (no deletions)
  - refuses to operate outside the project root

Usage:
  scripts/cleanup_fast_local_outputs.sh [options]

Options:
  --tmp-root DIR         tmp root to clean (default: ./tmp)
  --older-than-days N    only delete items older than N days (default: 30)
  --all                  delete all known fast-local outputs (ignores older-than-days)
  --apply                perform deletion (default is dry-run)
  --dry-run              force dry-run
  --verbose              print keep decisions
  --help                 show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tmp-root)
      TMP_ROOT="$2"
      shift 2
      ;;
    --older-than-days)
      OLDER_THAN_DAYS="$2"
      shift 2
      ;;
    --all)
      ALL=true
      shift
      ;;
    --apply)
      DRY_RUN=false
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$TMP_ROOT" != /* ]]; then
  TMP_ROOT="$PROJECT_ROOT/$TMP_ROOT"
fi

if ! [[ "$OLDER_THAN_DAYS" =~ ^[0-9]+$ ]]; then
  echo "[FAIL] --older-than-days must be a non-negative integer" >&2
  exit 1
fi

if [[ "$TMP_ROOT" != "$PROJECT_ROOT"/* ]]; then
  echo "[FAIL] refusing to operate outside project root (tmp_root=$TMP_ROOT project_root=$PROJECT_ROOT)" >&2
  exit 1
fi

if [[ ! -d "$TMP_ROOT" ]]; then
  echo "[WARN] tmp root not found: $TMP_ROOT"
  echo "[PASS] nothing to clean"
  exit 0
fi

declare -a DIR_PATTERNS
DIR_PATTERNS=(
  "minimal_ci_gate_compile_units_*"
  "minimal_ci_gate_module_units_*"
  "minimal_ci_gate_module_bin_*"
  "wave_b_ci_gate_reports_*"
  "run_all_module_tests_bin_*"
  "run_all_module_tests_reports_*"
  "run_all_module_tests_units_*"
  "phase2_bench_bin_*"
  "phase2_bench_results_*"
  "wave_c_b101_bench_bin_*"
  "wave_c_b101_compile_units_*"
  "wave_c_b101_module_reports_*"
  "wave_c_b101_module_bin_*"
  "wave_c_b101_module_units_*"
  "compile_all_modules_units_*"
  "bench_units_*"
)

find_mtime_args=()
if [[ "$ALL" != "true" ]]; then
  find_mtime_args=(-mtime "+$OLDER_THAN_DAYS")
fi

declare -a candidate_dirs
for pattern in "${DIR_PATTERNS[@]}"; do
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    candidate_dirs+=("$dir")
  done < <(
    find "$TMP_ROOT" -mindepth 1 -maxdepth 1 -type d -name "$pattern" "${find_mtime_args[@]}" 2>/dev/null | sort
  )
done

declare -a candidate_files
candidate_files=()

if [[ "$ALL" == "true" ]]; then
  if [[ -d "$TMP_ROOT/bin" ]]; then
    candidate_dirs+=("$TMP_ROOT/bin")
  fi
  if [[ -d "$TMP_ROOT/test-reports" ]]; then
    candidate_dirs+=("$TMP_ROOT/test-reports")
  fi
else
  for d in "$TMP_ROOT/bin" "$TMP_ROOT/test-reports"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      candidate_files+=("$file")
    done < <(find "$d" -type f -mtime "+$OLDER_THAN_DAYS" 2>/dev/null | sort)
  done
fi

dedup_sorted() {
  printf '%s\n' "$@" | sed '/^$/d' | sort -u
}

mapfile -t candidate_dirs < <(dedup_sorted "${candidate_dirs[@]}")
mapfile -t candidate_files < <(dedup_sorted "${candidate_files[@]}")

dir_count="${#candidate_dirs[@]}"
file_count="${#candidate_files[@]}"

echo "========================================"
echo "fafafa.ssl Fast-local Cleanup"
echo "========================================"
echo "[INFO] project_root: $PROJECT_ROOT"
echo "[INFO] tmp_root: $TMP_ROOT"
echo "[INFO] mode: $([[ "$DRY_RUN" == "true" ]] && echo DRY_RUN || echo APPLY)"
echo "[INFO] all: $ALL"
echo "[INFO] older_than_days: $OLDER_THAN_DAYS"
echo "[INFO] candidate_dirs: $dir_count"
echo "[INFO] candidate_files: $file_count"

if [[ "$dir_count" -eq 0 && "$file_count" -eq 0 ]]; then
  echo "[PASS] nothing to clean"
  exit 0
fi

if [[ "$VERBOSE" == "true" ]]; then
  for d in "${candidate_dirs[@]}"; do
    echo "[CANDIDATE-DIR] $d"
  done
  for f in "${candidate_files[@]}"; do
    echo "[CANDIDATE-FILE] $f"
  done
fi

deleted_dirs=0
deleted_files=0

if [[ "$DRY_RUN" == "false" ]]; then
  for f in "${candidate_files[@]}"; do
    if [[ "$f" == "$TMP_ROOT"/* && -f "$f" ]]; then
      rm -f -- "$f"
      deleted_files=$((deleted_files + 1))
    fi
  done

  for d in "${candidate_dirs[@]}"; do
    if [[ "$d" == "$TMP_ROOT"/* && -d "$d" ]]; then
      rm -rf -- "$d"
      deleted_dirs=$((deleted_dirs + 1))
    fi
  done
fi

echo "[INFO] deleted_dirs: $deleted_dirs"
echo "[INFO] deleted_files: $deleted_files"
echo "[PASS] cleanup finished"
