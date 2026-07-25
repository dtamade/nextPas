#!/usr/bin/env bash
# Compare nextPas bench_h2_server vs Go peer (same multiplex shape).
# Default: h2c (HS-0/HS-1). --tls: HTTPS ALPN h2 (C-D evidence bar; not package claim).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/h2_comparison"
CONNECTIONS=8
STREAMS=16
BATCHES=100
RUNS=1
USE_TLS=0
OUTPUT_PATH=""

usage() {
  cat <<'EOF'
usage: run_h2_comparison.sh [--connections N] [--streams N] [--batches N]
                            [--runs N] [--tls] [--output PATH]

Runs nextPas bench_h2_server (epoll multiplex) and Go compare_h2 peer with the
same shape. Default transport is h2c prior-knowledge. Pass --tls for HTTPS
ALPN h2 (self-signed both sides; C-D). With --runs N (default 1), repeats each
side N times and reports median req/s and ratio of medians (H1 E3 style).
Prints summary lines and nextPas/Go peer gate (≥ 0.80 on median ratio).
Does not claim package scale-ready.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --connections) CONNECTIONS="${2:?}"; shift 2 ;;
    --streams) STREAMS="${2:?}"; shift 2 ;;
    --batches) BATCHES="${2:?}"; shift 2 ;;
    --runs) RUNS="${2:?}"; shift 2 ;;
    --tls) USE_TLS=1; shift ;;
    --output) OUTPUT_PATH="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ "${RUNS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "--runs must be a positive integer" >&2
  exit 2
fi
if ! [[ "${CONNECTIONS}" =~ ^[1-9][0-9]*$ && "${STREAMS}" =~ ^[1-9][0-9]*$ && "${BATCHES}" =~ ^[1-9][0-9]*$ ]]; then
  echo "--connections, --streams, and --batches must be positive integers" >&2
  exit 2
fi

TLS_ARGS=()
TRANSPORT="h2c-prior-knowledge"
COMPARISON_NAME="http.server.h2.comparison"
if [[ "${USE_TLS}" -eq 1 ]]; then
  TLS_ARGS=(--tls)
  TRANSPORT="tls-alpn-h2"
  COMPARISON_NAME="http.server.h2.tls.comparison"
  BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/h2_tls_comparison"
fi

mkdir -p "${BUILD_DIR}"

echo "=== build nextPas bench_h2_server ==="
make -C "${SCRIPT_DIR}/bench_h2_server" build

echo "=== build Go h2 peer ==="
(
  cd "${SCRIPT_DIR}/compare_h2"
  go mod download
  go build -o "${BUILD_DIR}/bench_h2_server_go" .
)

NEXTPAS_BIN="${CORE_ROOT}/build/projects/nextpas.core.http/bench_h2_server/bench_h2_server"
GO_BIN="${BUILD_DIR}/bench_h2_server_go"
SHAPE=(--connections "${CONNECTIONS}" --streams "${STREAMS}" --batches "${BATCHES}")

RESULTS_TMP="$(mktemp "${BUILD_DIR}/h2-comparison-results.XXXXXX")"
trap 'rm -f "${RESULTS_TMP}"' EXIT
: > "${RESULTS_TMP}"

parse_field() {
  local log="$1"
  local key="$2"
  awk -F= -v k="${key}" '$1==k {v=$2} END{print v}' "${log}"
}

# TSV: run_index \t impl \t req_s \t completed \t failed \t stable
append_row() {
  local run_index="$1"
  local impl="$2"
  local log="$3"
  local req_s completed failed stable
  req_s="$(parse_field "${log}" "req/s")"
  completed="$(parse_field "${log}" "completed")"
  failed="$(parse_field "${log}" "failed")"
  stable="$(parse_field "${log}" "stable")"
  if [[ -z "${req_s}" || -z "${stable}" ]]; then
    echo "unable to parse ${impl} run=${run_index} log=${log}" >&2
    cat "${log}" >&2 || true
    exit 1
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${run_index}" "${impl}" "${req_s}" "${completed:-}" "${failed:-}" "${stable}" \
    >> "${RESULTS_TMP}"
}

{
  echo "comparison=${COMPARISON_NAME}"
  echo "shape=connections=${CONNECTIONS} streams=${STREAMS} batches=${BATCHES}"
  echo "summary_shape=${CONNECTIONS}x${STREAMS}x${BATCHES}"
  echo "transport=${TRANSPORT}"
  echo "runs=${RUNS}"
  echo "date=$(date -Iseconds 2>/dev/null || date)"
  echo

  for run_index in $(seq 1 "${RUNS}"); do
    echo "run=${run_index}"
    np_log="${BUILD_DIR}/nextpas.run${run_index}.log"
    go_log="${BUILD_DIR}/go.run${run_index}.log"

    echo "section=nextpas"
    "${NEXTPAS_BIN}" --mode multiplex --backend epoll "${SHAPE[@]}" "${TLS_ARGS[@]}" | tee "${np_log}"
    append_row "${run_index}" "nextpas" "${np_log}"
    echo

    echo "section=go"
    "${GO_BIN}" "${SHAPE[@]}" "${TLS_ARGS[@]}" | tee "${go_log}"
    append_row "${run_index}" "go" "${go_log}"
    echo
  done

  # Also keep last-run aliases for single-run tooling compatibility
  cp -f "${BUILD_DIR}/nextpas.run${RUNS}.log" "${BUILD_DIR}/nextpas.log"
  cp -f "${BUILD_DIR}/go.run${RUNS}.log" "${BUILD_DIR}/go.log"

  awk -F $'\t' -v comparison="${COMPARISON_NAME}" -v transport="${TRANSPORT}" '
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

    {
      impl = $2;
      count[impl]++;
      req_values[impl, count[impl]] = $3 + 0.0;
      completed_values[impl, count[impl]] = $4 + 0.0;
      failed_values[impl, count[impl]] = $5 + 0.0;
      stable_values[impl, count[impl]] = $6 + 0;
    }

    END {
      for (impl in count) {
        delete current_req;
        all_stable = 1;
        for (i = 1; i <= count[impl]; i++) {
          current_req[i] = req_values[impl, i];
          if (stable_values[impl, i] != 1) {
            all_stable = 0;
          }
        }
        med_req = median(current_req, count[impl]);
        printf "summary_impl=%s runs=%d median_req/s=%.0f all_stable=%d\n",
          impl, count[impl], med_req, all_stable;
        if (impl == "nextpas") {
          np_med = med_req;
          np_stable = all_stable;
          np_runs = count[impl];
        } else if (impl == "go") {
          go_med = med_req;
          go_stable = all_stable;
          go_runs = count[impl];
        }
      }

      ratio = "n/a";
      gate = "n/a";
      if (np_runs > 0 && go_runs > 0 && go_med > 0) {
        ratio_val = np_med / go_med;
        ratio = sprintf("%.2f", ratio_val);
        if (np_stable == 1 && go_stable == 1 && ratio_val >= 0.80) {
          gate = "Met";
        } else {
          gate = "NotMet";
        }
      } else if (np_runs > 0 && go_runs > 0) {
        gate = "NotMet";
      }

      printf "summary=%s\n", comparison;
      printf "summary_transport=%s\n", transport;
      printf "summary_median_nextpas_req/s=%.0f\n", np_med + 0;
      printf "summary_median_go_req/s=%.0f\n", go_med + 0;
      printf "summary_nextpas_req/s=%.0f\n", np_med + 0;
      printf "summary_go_req/s=%.0f\n", go_med + 0;
      printf "summary_ratio_nextpas_over_go=%s\n", ratio;
      printf "summary_nextpas_stable=%d\n", np_stable + 0;
      printf "summary_go_stable=%d\n", go_stable + 0;
      printf "summary_gate_peer_0_80=%s\n", gate;
    }
  ' "${RESULTS_TMP}"
} | tee "${BUILD_DIR}/latest.md"

if [[ -n "${OUTPUT_PATH}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
  cp "${BUILD_DIR}/latest.md" "${OUTPUT_PATH}"
  echo "wrote ${OUTPUT_PATH}"
fi
