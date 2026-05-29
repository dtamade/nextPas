#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_REL="tmp/test_linux_openssl_matrix_openssl3_lib_dir_injection_$(date +%s)"
WORK_DIR="$ROOT_DIR/$WORK_REL"
FAKE_ROOT="$WORK_DIR/fake_project"
FAKE_SCRIPTS="$FAKE_ROOT/scripts"
FAKE_BIN="$WORK_DIR/fake_bin"
FLAG_FILE="$WORK_DIR/lib_injected.flag"
LIB_PATH_PAYLOAD="$WORK_DIR/lib'; touch '$FLAG_FILE'; echo '"
OPENSSL_LD_PATH_LOG="$WORK_DIR/openssl_ld_library_path.log"
STDOUT_LOG="$WORK_DIR/stdout.log"
STDERR_LOG="$WORK_DIR/stderr.log"

mkdir -p "$FAKE_SCRIPTS" "$FAKE_BIN"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  echo "[FAIL] $1"
  exit 1
}

cp "$ROOT_DIR/scripts/run_linux_openssl_matrix_draft.sh" "$FAKE_SCRIPTS/"

cat > "$FAKE_BIN/openssl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${LD_LIBRARY_PATH:-}" >> "${OPENSSL_LD_PATH_LOG:?}"
echo "OpenSSL fake"
EOF

cat > "$FAKE_BIN/fpc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "3.2.2"
EOF

cat > "$FAKE_SCRIPTS/compile_all_modules.py" <<'EOF'
#!/usr/bin/env python3
print("compile ok")
EOF

cat > "$FAKE_SCRIPTS/run_all_module_tests.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

cat > "$FAKE_SCRIPTS/run_phase2_performance_baseline.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

chmod +x "$FAKE_BIN"/* "$FAKE_SCRIPTS/"*.sh "$FAKE_SCRIPTS/compile_all_modules.py"

set +e
(
  cd "$FAKE_ROOT"
  PATH="$FAKE_BIN:$PATH" \
  OPENSSL_LD_PATH_LOG="$OPENSSL_LD_PATH_LOG" \
  bash scripts/run_linux_openssl_matrix_draft.sh \
    --skip-compile \
    --skip-phase2-dryrun \
    --openssl3-lib-dir "$LIB_PATH_PAYLOAD" >"$STDOUT_LOG" 2>"$STDERR_LOG"
)
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  fail "linux openssl matrix should treat openssl3 lib dir payload as data and complete with fake green tools"
fi

if [[ -e "$FLAG_FILE" ]]; then
  fail "linux openssl matrix should not execute shell content embedded in --openssl3-lib-dir"
fi

if [[ ! -f "$OPENSSL_LD_PATH_LOG" ]]; then
  fail "fake openssl should observe LD_LIBRARY_PATH"
fi

if ! rg -F --quiet -- "${LIB_PATH_PAYLOAD}:" "$OPENSSL_LD_PATH_LOG"; then
  fail "linux openssl matrix should pass the full openssl3 lib dir payload as LD_LIBRARY_PATH data"
fi

echo "[PASS] linux openssl matrix openssl3-lib-dir injection contract passed"
