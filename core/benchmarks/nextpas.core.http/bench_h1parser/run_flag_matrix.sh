#!/usr/bin/env bash
set -euo pipefail

if [ "${PATH:-}" = "" ]; then
  export PATH="/usr/local/bin:/usr/bin:/bin"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_ROOT="$CORE_ROOT/build/projects/nextpas.core.http/bench_h1parser"

SMOKE=0
PERF_ENABLED=0
RUNS=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --smoke)
      SMOKE=1
      ;;
    --perf)
      PERF_ENABLED=1
      ;;
    --no-perf)
      PERF_ENABLED=0
      ;;
    --runs)
      shift
      if [ "$#" -eq 0 ]; then
        echo "--runs requires a positive integer" >&2
        exit 2
      fi
      RUNS="$1"
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

case "$RUNS" in
  ''|*[!0-9]*)
    echo "--runs requires a positive integer" >&2
    exit 2
    ;;
esac

if [ "$RUNS" -lt 1 ]; then
  echo "--runs requires a positive integer" >&2
  exit 2
fi

BENCH_MAX_ITERS="${NEXTPAS_BENCH_MAX_ITERS:-}"
if [ "$BENCH_MAX_ITERS" = "" ]; then
  if [ "$SMOKE" = "1" ]; then
    BENCH_MAX_ITERS=2000
  else
    BENCH_MAX_ITERS=100000
  fi
fi

BENCH_FILTER="${NEXTPAS_BENCH_FILTER:-raw llhttp: 10 headers}"
C_BENCH_FILTER="${NEXTPAS_C_BENCH_FILTER:-C ${BENCH_FILTER}}"
LLHTTP_ROOT_VALUE="${LLHTTP_ROOT:-${NEXTPAS_LLHTTP_ROOT:-}}"

if [ "$SMOKE" = "1" ]; then
  OUTPUT_DIR="${NEXTPAS_FLAG_MATRIX_OUTPUT_DIR:-$BUILD_ROOT/flag_matrix/smoke}"
else
  RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
  OUTPUT_DIR="${NEXTPAS_FLAG_MATRIX_OUTPUT_DIR:-$BUILD_ROOT/flag_matrix/$RUN_ID}"
fi

if [ "${NEXTPAS_FLAG_MATRIX_OUTPUT_DIR:-}" != "" ]; then
  case "$OUTPUT_DIR" in
    "$BUILD_ROOT/flag_matrix"|"$BUILD_ROOT/flag_matrix/"*)
      ;;
    *)
      echo "unsafe output dir: $OUTPUT_DIR" >&2
      echo "allowed root: $BUILD_ROOT/flag_matrix" >&2
      exit 2
      ;;
  esac
  case "$OUTPUT_DIR" in
    ../*|*/..|*/../*|*//*)
      echo "unsafe output dir: $OUTPUT_DIR" >&2
      echo "relative parent segments are not allowed" >&2
      exit 2
      ;;
  esac
fi

LOG_DIR="$OUTPUT_DIR/logs"
PERF_DIR="$OUTPUT_DIR/perf"
RESULTS_PATH="$OUTPUT_DIR/results.tsv"
SUMMARY_PATH="$OUTPUT_DIR/summary.tsv"
ENV_PATH="$OUTPUT_DIR/env.txt"
PERF_CHECK_PATH="$PERF_DIR/perf-check.txt"

rm -rf "$OUTPUT_DIR"
mkdir -p "$LOG_DIR" "$PERF_DIR"

PERF_USABLE=0
if [ "$PERF_ENABLED" = "1" ] && command -v perf >/dev/null 2>&1; then
  if perf stat -e cycles -o "$PERF_CHECK_PATH" -- true >/dev/null 2>&1; then
    PERF_USABLE=1
  fi
fi

{
  echo "git_head=$(git -C "$CORE_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "core_root=$CORE_ROOT"
  echo "bench_max_iters=$BENCH_MAX_ITERS"
  echo "bench_filter=$BENCH_FILTER"
  echo "c_bench_filter=$C_BENCH_FILTER"
  echo "llhttp_root=$LLHTTP_ROOT_VALUE"
  echo "runs=$RUNS"
  echo "perf_requested=$PERF_ENABLED"
  echo "perf_usable=$PERF_USABLE"
  echo "fpc_version=$(fpc -iV 2>/dev/null || echo unknown)"
  echo "cc_version=$(${CC:-cc} --version 2>/dev/null | head -n 1 || echo unknown)"
} > "$ENV_PATH"

printf 'variant\timpl\tbenchmark\trun\titerations\tns_per_op\tops_per_sec\tflags\n' > "$RESULTS_PATH"

append_rows() {
  local variant="$1"
  local impl="$2"
  local flags="$3"
  local output_file="$4"
  local run_index="$5"

  sed -nE 's/^[[:space:]]*(.*[^[:space:]])[[:space:]]+([0-9]+)[[:space:]]+iters[[:space:]]+([0-9]+(\.[0-9]+)?)[[:space:]]+ns\/op[[:space:]]+([0-9]+(\.[0-9]+)?)[[:space:]]+ops\/s[[:space:]]*$/\1\t\2\t\3\t\5/p' "$output_file" |
  while IFS=$'\t' read -r benchmark iterations ns_per_op ops_per_sec; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$variant" "$impl" "$benchmark" "$run_index" "$iterations" "$ns_per_op" "$ops_per_sec" "$flags" >> "$RESULTS_PATH"
  done
}

write_summary() {
  awk -F $'\t' '
    function sort_values(values, count,    i, j, tmp) {
      for (i = 1; i < count; i++) {
        for (j = i + 1; j <= count; j++) {
          if (values[j] < values[i]) {
            tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
          }
        }
      }
    }

    function median(values, count,    copy, i) {
      delete copy;
      for (i = 1; i <= count; i++) {
        copy[i] = values[i];
      }
      sort_values(copy, count);
      if ((count % 2) == 1) {
        return copy[int((count + 1) / 2)];
      }
      return (copy[int(count / 2)] + copy[int(count / 2) + 1]) / 2.0;
    }

    BEGIN { OFS = FS; }

    NR == 1 { next }

    {
      key = $1 FS $2 FS $3 FS $8;
      variant[key] = $1;
      impl[key] = $2;
      benchmark[key] = $3;
      flags[key] = $8;
      count[key]++;
      ns_values[key, count[key]] = $6 + 0.0;
    }

    END {
      for (key in count) {
        delete current_values;
        for (i = 1; i <= count[key]; i++) {
          current_values[i] = ns_values[key, i];
        }
        median_ns = median(current_values, count[key]);
        if (median_ns > 0.0) {
          median_ops = 1000000000.0 / median_ns;
        } else {
          median_ops = 0.0;
        }
        printf "%s%s%s%s%s%s%d%s%.1f%s%.0f%s%s\n",
          variant[key], OFS, impl[key], OFS, benchmark[key], OFS,
          count[key], OFS, median_ns, OFS, median_ops, OFS, flags[key];
      }
    }
  ' "$RESULTS_PATH" | sort -t $'\t' -k1,1 -k2,2 -k3,3 > "$SUMMARY_PATH.tmp"

  {
    printf 'variant\timpl\tbenchmark\truns\tmedian_ns_per_op\tmedian_ops_per_sec\tflags\n'
    cat "$SUMMARY_PATH.tmp"
  } > "$SUMMARY_PATH"
  rm -f "$SUMMARY_PATH.tmp"
}

run_with_optional_perf() {
  local perf_name="$1"
  shift

  if [ "$PERF_USABLE" = "1" ]; then
    perf stat \
      -e cycles,instructions,branches,branch-misses,cache-misses \
      -o "$PERF_DIR/$perf_name.txt" \
      -- "$@"
  else
    "$@"
  fi
}

run_pascal_variant() {
  local variant="$1"
  local flags="$2"
  local build_dir="$OUTPUT_DIR/build/$variant"
  local binary="$build_dir/bench_h1parser"
  local run_index
  local output_file

  rm -rf "$build_dir"
  make -C "$SCRIPT_DIR" build BUILD_DIR="$build_dir" EXTRA_FLAGS="$flags" > "$LOG_DIR/$variant.build.txt" 2>&1
  for run_index in $(seq 1 "$RUNS"); do
    output_file="$LOG_DIR/$variant.run${run_index}.txt"
    NEXTPAS_BENCH_MAX_ITERS="$BENCH_MAX_ITERS" \
    NEXTPAS_BENCH_FILTER="$BENCH_FILTER" \
      run_with_optional_perf "$variant.run${run_index}" "$binary" > "$output_file" 2>&1
    append_rows "$variant" "pascal" "$flags" "$output_file" "$run_index"
  done
}

run_c_variant() {
  local variant="$1"
  local flags="$2"
  local build_dir="$OUTPUT_DIR/build/$variant"
  local binary="$build_dir/bench_llhttp_c"
  local run_index
  local output_file

  if [ "$LLHTTP_ROOT_VALUE" = "" ]; then
    echo "skip $variant: LLHTTP_ROOT is not set" > "$LOG_DIR/$variant.skip.txt"
    return
  fi

  rm -rf "$build_dir"
  make -C "$SCRIPT_DIR/compare_c" build BUILD_DIR="$build_dir" \
    LLHTTP_ROOT="$LLHTTP_ROOT_VALUE" EXTRA_CFLAGS="$flags" > "$LOG_DIR/$variant.build.txt" 2>&1
  for run_index in $(seq 1 "$RUNS"); do
    output_file="$LOG_DIR/$variant.run${run_index}.txt"
    NEXTPAS_BENCH_MAX_ITERS="$BENCH_MAX_ITERS" \
    NEXTPAS_BENCH_FILTER="$C_BENCH_FILTER" \
      run_with_optional_perf "$variant.run${run_index}" "$binary" > "$output_file" 2>&1
    append_rows "$variant" "c" "$flags" "$output_file" "$run_index"
  done
}

run_pascal_variant "pascal-default" ""
run_c_variant "c-default" ""

if [ "$SMOKE" != "1" ]; then
  run_pascal_variant "pascal-coreavx2" "-CpCOREAVX2 -CfAVX2"
  run_pascal_variant "pascal-extra-opts" "-OoREGVAR -OoCSE -OoDFA -OoPEEPHOLE -OoLOOPUNROLL"
  run_c_variant "c-native" "-march=native"
fi

write_summary

echo "flag_matrix_output=$OUTPUT_DIR"
echo "results=$RESULTS_PATH"
echo "summary=$SUMMARY_PATH"
echo "env=$ENV_PATH"
