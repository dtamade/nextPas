#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_all_module_tests.sh"

echo "[TEST] run_all_module_tests timeout portability contract"

if ! command -v fpc >/dev/null 2>&1; then
  echo "[SKIP] missing fpc in PATH"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[SKIP] missing python3 in PATH"
  exit 0
fi

WORK_DIR="$ROOT_DIR/tmp/test_run_all_module_tests_timeout_portability_contract"
FAKE_BIN="$WORK_DIR/fake-bin"
LOG_FILE="$WORK_DIR/run.log"

rm -rf "$WORK_DIR"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/timeout" <<'EOF'
#!/usr/bin/env bash
echo "[fake-timeout] intentionally unavailable (contract)" >&2
exit 127
EOF
chmod +x "$FAKE_BIN/timeout"

# Force the script to see a broken `timeout` in PATH (simulates macOS runner without GNU timeout).
export PATH="$FAKE_BIN:$PATH"

# Keep outputs isolated and cheap.
export FAFAFA_FAST_LOCAL=1

if ! bash "$SCRIPT" --modules PKCS7 --fast-local >"$LOG_FILE" 2>&1; then
  echo "[FAIL] expected module tests to succeed even when timeout is unavailable"
  echo "[INFO] tail log: $LOG_FILE"
  tail -200 "$LOG_FILE" || true
  exit 1
fi

echo "[PASS] run_all_module_tests timeout portability contract passed"
