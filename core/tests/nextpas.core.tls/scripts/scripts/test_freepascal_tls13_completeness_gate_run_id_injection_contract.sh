#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_REL="tmp/test_fp_tls13_gate_run_id_injection_$(date +%s)"
WORK_DIR="$ROOT_DIR/$WORK_REL"
FAKE_ROOT="$WORK_DIR/fake_project"
FAKE_SCRIPTS="$FAKE_ROOT/scripts"
FAKE_REPORTS_REL="tmp/test-reports"
FAKE_REPORTS_DIR="$FAKE_ROOT/$FAKE_REPORTS_REL"
MARKER="$FAKE_ROOT/freepascal_tls13_gate_injected.marker"
FAKE_FPC_LOG="$WORK_DIR/fake_fpc.log"
MALICIOUS_RUN_ID="fp_tls13_gate'; touch freepascal_tls13_gate_injected.marker; #'"
SUMMARY_FILE="$FAKE_REPORTS_DIR/freepascal_tls13_completeness_${MALICIOUS_RUN_ID}.md"
STDOUT_LOG="$WORK_DIR/stdout.log"
STDERR_LOG="$WORK_DIR/stderr.log"

cleanup() {
  rm -rf "$WORK_DIR"
}

mkdir -p "$FAKE_SCRIPTS" "$FAKE_REPORTS_DIR"
trap cleanup EXIT

fail() {
  echo "[FAIL] $1"
  exit 1
}

cp "$ROOT_DIR/scripts/run_freepascal_tls13_completeness_gate.sh" "$FAKE_SCRIPTS/"

cat > "$FAKE_ROOT/fpc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FAFAFA_FAKE_FPC_LOG:?}"
printf '__RUN__\n' >> "$log_file"
printf '%s\n' "$@" >> "$log_file"

out_path=""
for arg in "$@"; do
  case "$arg" in
    -o*)
      out_path="${arg#-o}"
      ;;
  esac
done

if [[ -z "$out_path" ]]; then
  echo "[FAIL] fake fpc expected -o<path>" >&2
  exit 1
fi

mkdir -p "$(dirname "$out_path")"
cat > "$out_path" <<'INNER'
#!/usr/bin/env bash
exit 0
INNER
chmod +x "$out_path"
EOF

chmod +x "$FAKE_ROOT/fpc"

set +e
(
  cd "$FAKE_ROOT"
  PATH="$FAKE_ROOT:$PATH" \
  FAFAFA_FAKE_FPC_LOG="$FAKE_FPC_LOG" \
  bash scripts/run_freepascal_tls13_completeness_gate.sh \
    --fast-local \
    --run-id "$MALICIOUS_RUN_ID" >"$STDOUT_LOG" 2>"$STDERR_LOG"
)
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  fail "freepascal tls13 completeness gate should stay green with fake green fpc/executables"
fi

if [[ -e "$MARKER" ]]; then
  fail "freepascal tls13 completeness gate should not execute shell content embedded in --run-id"
fi

if [[ ! -f "$FAKE_FPC_LOG" ]]; then
  fail "fake fpc should have been invoked"
fi

run_count="$(rg -c '^__RUN__$' "$FAKE_FPC_LOG" || true)"
if [[ "$run_count" != "18" ]]; then
  fail "focused gate should invoke fake fpc 18 times"
fi

if ! rg -F --quiet -- "$MALICIOUS_RUN_ID" "$FAKE_FPC_LOG"; then
  fail "focused gate should pass the full run-id payload as data into fake fpc paths"
fi

if [[ ! -f "$SUMMARY_FILE" ]]; then
  fail "focused gate should generate the summary report under tmp/test-reports"
fi

if ! rg -F --quiet -- '| `test_freepascal_tls13_early_data` | PASS |' "$SUMMARY_FILE"; then
  fail "summary should record PASS rows in the fake green scenario"
fi

echo "[PASS] freepascal tls13 completeness gate run-id injection contract passed"
