#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_REL="tmp/test_tls13_signer_gate_bundle_run_id_injection_$(date +%s)"
WORK_DIR="$ROOT_DIR/$WORK_REL"
FAKE_ROOT="$WORK_DIR/fake_project"
FAKE_SCRIPTS="$FAKE_ROOT/scripts"
REPORTS_DIR="out"
OUTPUT_FILE_REL="$REPORTS_DIR/bundle.md"
OUTPUT_FILE_ABS="$FAKE_ROOT/$OUTPUT_FILE_REL"
RUN_ID_LOG="$WORK_DIR/ci_run_id.log"
MARKER_NAME="run_id_injected.marker"
MARKER="$FAKE_ROOT/$MARKER_NAME"
MALICIOUS_RUN_ID="tls13_bundle'; touch $MARKER_NAME; echo '"
STDOUT_LOG="$WORK_DIR/stdout.log"
STDERR_LOG="$WORK_DIR/stderr.log"

cleanup() {
  rm -rf "$WORK_DIR"
}

mkdir -p "$FAKE_SCRIPTS"
trap cleanup EXIT

fail() {
  echo "[FAIL] $1"
  exit 1
}

cp "$ROOT_DIR/scripts/run_tls13_signer_gate_bundle.sh" "$FAKE_SCRIPTS/"

cat > "$FAKE_SCRIPTS/run_tls13_signer_gate_ci.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
run_id="${FAFAFA_TLS13_SIGNER_GATE_RUN_ID:?}"
output_dir="${FAFAFA_TLS13_SIGNER_GATE_OUTPUT_DIR:?}"
printf '%s\n' "$run_id" > "${FAFAFA_FAKE_CI_RUN_ID_LOG:?}"
mkdir -p "$output_dir"
cat > "$output_dir/wave_b_ci_gate_summary_tls13_signer_${run_id}.md" <<'SUMMARY'
Overall Status: **PASS**
| step | exit | status |
| tls13_signer_purity | 0 | PASS |
| tls13_servercertverify_bench | 0 | PASS |
SUMMARY
cat > "$output_dir/wave_b_tls13_signer_${run_id}.json" <<'JSON'
{
  "bench_scheme": "rsa_pkcs1_sha256",
  "bench_iterations": "2",
  "bench_warmup": "1",
  "crt_avg_ms": "1.0",
  "d_avg_ms": "0.5",
  "speedup_d_over_crt": "2.0"
}
JSON
cat > "$output_dir/tls13_signer_bench_history_${run_id}.md" <<'HISTORY'
# history
HISTORY
exit 0
EOF

cat > "$FAKE_SCRIPTS/generate_tls13_signer_gate_snapshot.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$(dirname "$output")"
cat > "$output" <<'SNAPSHOT'
- snapshot_state: **GREEN**
SNAPSHOT
exit 0
EOF

cat > "$FAKE_SCRIPTS/export_tls13_signer_gate_status_json.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$(dirname "$output")"
cat > "$output" <<'JSON'
{"overall_state": "HEALTHY"}
JSON
exit 0
EOF

chmod +x "$FAKE_SCRIPTS/"*.sh

set +e
(
  cd "$FAKE_ROOT"
  FAFAFA_FAKE_CI_RUN_ID_LOG="$RUN_ID_LOG" \
  FAFAFA_TLS13_SIGNER_GATE_ARCHIVE=0 \
  bash scripts/run_tls13_signer_gate_bundle.sh \
    --run-id "$MALICIOUS_RUN_ID" \
    --reports-dir "$REPORTS_DIR" \
    --output "$OUTPUT_FILE_REL" >"$STDOUT_LOG" 2>"$STDERR_LOG"
)
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  fail "tls13 signer gate bundle should stay green with fake green runners"
fi

if [[ -e "$MARKER" ]]; then
  fail "tls13 signer gate bundle should not execute shell content embedded in --run-id"
fi

if [[ ! -f "$RUN_ID_LOG" ]]; then
  fail "fake tls13 signer gate ci should observe the run-id env"
fi

if ! rg -Fx -- "$MALICIOUS_RUN_ID" "$RUN_ID_LOG" >/dev/null; then
  fail "tls13 signer gate bundle should pass the full run-id payload as data to the nested ci runner"
fi

if [[ ! -f "$OUTPUT_FILE_ABS" ]]; then
  fail "expected tls13 signer gate bundle report to be generated"
fi

if ! rg -n "^- overall: \\*\\*PASS\\*\\*" "$OUTPUT_FILE_ABS" >/dev/null; then
  fail "tls13 signer gate bundle report should stay PASS in the fake green scenario"
fi

echo "[PASS] tls13 signer gate bundle run-id injection contract passed"
