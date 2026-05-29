#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_ID="${FAFAFA_TLS13_SIGNER_GATE_RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
OUTPUT_DIR_REL="${FAFAFA_TLS13_SIGNER_GATE_OUTPUT_DIR:-test-reports}"

BENCH_ITERATIONS="${FAFAFA_TLS13_SIGN_BENCH_ITERATIONS:-2}"
BENCH_WARMUP="${FAFAFA_TLS13_SIGN_BENCH_WARMUP:-1}"
BENCH_SCHEME="${FAFAFA_TLS13_SIGN_BENCH_SCHEME:-rsa_pkcs1_sha256}"
BENCH_KEY="${FAFAFA_TLS13_SIGN_BENCH_KEY:-tests/certificate/test_certs/signer_key.pem}"
BENCH_TIMEOUT="${FAFAFA_TLS13_SIGN_BENCH_TIMEOUT:-120}"
HISTORY_LIMIT="${FAFAFA_TLS13_SIGN_BENCH_HISTORY_LIMIT:-20}"

ARCHIVE_ENABLED="${FAFAFA_TLS13_SIGNER_GATE_ARCHIVE:-1}"
ARCHIVE_PROFILE="${FAFAFA_TLS13_SIGNER_GATE_ARCHIVE_PROFILE:-pr}"
ARCHIVE_ROOT="${FAFAFA_TLS13_SIGNER_GATE_ARCHIVE_ROOT:-artifacts/ci}"

if [[ "$OUTPUT_DIR_REL" = /* ]]; then
  echo "[tls13-gate] OUTPUT_DIR must be relative to repo root: $OUTPUT_DIR_REL" >&2
  exit 2
fi

if [[ ! "$BENCH_ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$BENCH_ITERATIONS" -le 0 ]]; then
  echo "[tls13-gate] invalid FAFAFA_TLS13_SIGN_BENCH_ITERATIONS: $BENCH_ITERATIONS" >&2
  exit 2
fi

if [[ ! "$BENCH_WARMUP" =~ ^[0-9]+$ ]] || [[ "$BENCH_WARMUP" -lt 0 ]]; then
  echo "[tls13-gate] invalid FAFAFA_TLS13_SIGN_BENCH_WARMUP: $BENCH_WARMUP" >&2
  exit 2
fi

if [[ ! "$BENCH_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$BENCH_TIMEOUT" -le 0 ]]; then
  echo "[tls13-gate] invalid FAFAFA_TLS13_SIGN_BENCH_TIMEOUT: $BENCH_TIMEOUT" >&2
  exit 2
fi

if [[ ! "$HISTORY_LIMIT" =~ ^[0-9]+$ ]] || [[ "$HISTORY_LIMIT" -le 0 ]]; then
  echo "[tls13-gate] invalid FAFAFA_TLS13_SIGN_BENCH_HISTORY_LIMIT: $HISTORY_LIMIT" >&2
  exit 2
fi

if [[ "$ARCHIVE_ENABLED" != "0" && "$ARCHIVE_ENABLED" != "1" ]]; then
  echo "[tls13-gate] invalid FAFAFA_TLS13_SIGNER_GATE_ARCHIVE: $ARCHIVE_ENABLED (expect 0|1)" >&2
  exit 2
fi

SUMMARY_REL="$OUTPUT_DIR_REL/wave_b_ci_gate_summary_tls13_signer_${RUN_ID}.md"
BENCH_JSON_REL="$OUTPUT_DIR_REL/wave_b_tls13_signer_${RUN_ID}.json"
HISTORY_MD_REL="$OUTPUT_DIR_REL/tls13_signer_bench_history_${RUN_ID}.md"

mkdir -p "$PROJECT_ROOT/$OUTPUT_DIR_REL"

cd "$PROJECT_ROOT"

echo "[tls13-gate] run_id=$RUN_ID"
echo "[tls13-gate] output_dir=$OUTPUT_DIR_REL"

bash scripts/run_wave_b_ci_gate.sh \
  --run-id "$RUN_ID" \
  --only-tls13-sign-bench \
  --with-tls13-sign-purity-check \
  --summary-out "$SUMMARY_REL" \
  --tls13-sign-bench-iterations "$BENCH_ITERATIONS" \
  --tls13-sign-bench-warmup "$BENCH_WARMUP" \
  --tls13-sign-bench-scheme "$BENCH_SCHEME" \
  --tls13-sign-bench-key "$BENCH_KEY" \
  --tls13-sign-bench-timeout "$BENCH_TIMEOUT" \
  --tls13-sign-bench-json-out "$BENCH_JSON_REL"

FAFAFA_TLS13_SIGN_BENCH_HISTORY_LIMIT="$HISTORY_LIMIT" \
FAFAFA_TLS13_SIGN_BENCH_HISTORY_OUT="$HISTORY_MD_REL" \
bash scripts/summarize_tls13_signer_bench_history.sh >/dev/null

if [[ "$ARCHIVE_ENABLED" == "1" ]]; then
  ARCHIVE_RUN_ID="tls13_signer_${RUN_ID}"
  bash scripts/archive_ci_artifacts_draft.sh \
    --profile "$ARCHIVE_PROFILE" \
    --run-id "$ARCHIVE_RUN_ID" \
    --output-root "$ARCHIVE_ROOT"

  echo "[tls13-gate] archive_run_id=$ARCHIVE_RUN_ID"
  echo "[tls13-gate] archive_root=$ARCHIVE_ROOT"
fi

echo "[tls13-gate] summary=$SUMMARY_REL"
echo "[tls13-gate] bench_json=$BENCH_JSON_REL"
echo "[tls13-gate] history_md=$HISTORY_MD_REL"
echo "[tls13-gate] PASS"
