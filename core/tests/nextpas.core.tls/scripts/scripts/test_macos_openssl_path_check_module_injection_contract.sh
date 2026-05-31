#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_REL="tmp/test_macos_openssl_path_check_module_injection_$(date +%s)"
WORK_DIR="$ROOT_DIR/$WORK_REL"
FAKE_ROOT="$WORK_DIR/fake_project"
FAKE_SCRIPTS="$FAKE_ROOT/scripts"
FAKE_OPENSSL="$WORK_DIR/fake_openssl"
FAKE_BIN="$WORK_DIR/fake_bin"
FLAG_FILE="$WORK_DIR/module_injected.flag"
MODULE_ARGS_LOG="$WORK_DIR/module_args.log"
STDOUT_LOG="$WORK_DIR/stdout.log"
STDERR_LOG="$WORK_DIR/stderr.log"
MALICIOUS_MODULES="PKCS7; touch '$FLAG_FILE'; #"

mkdir -p "$FAKE_SCRIPTS" "$FAKE_OPENSSL/lib" "$FAKE_OPENSSL/include/openssl" "$FAKE_OPENSSL/bin" "$FAKE_BIN"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  echo "[FAIL] $1"
  exit 1
}

: > "$FAKE_OPENSSL/lib/libcrypto.dylib"
: > "$FAKE_OPENSSL/lib/libssl.dylib"
: > "$FAKE_OPENSSL/include/openssl/ssl.h"

cp "$ROOT_DIR/scripts/run_macos_openssl_path_check_draft.sh" "$FAKE_SCRIPTS/"

cat > "$FAKE_OPENSSL/bin/openssl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "OpenSSL fake"
EOF

cat > "$FAKE_BIN/fpc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "3.2.2"
EOF

cat > "$FAKE_SCRIPTS/run_all_module_tests.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${MODULE_ARGS_LOG:?}"
exit 0
EOF

cat > "$FAKE_SCRIPTS/run_phase2_performance_baseline.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

chmod +x "$FAKE_OPENSSL/bin/openssl" "$FAKE_BIN/fpc" "$FAKE_SCRIPTS/"*.sh

set +e
(
  cd "$FAKE_ROOT"
  PATH="$FAKE_BIN:$PATH" \
  MODULE_ARGS_LOG="$MODULE_ARGS_LOG" \
  OSTYPE=darwin23 \
  bash scripts/run_macos_openssl_path_check_draft.sh \
    --openssl-root "$FAKE_OPENSSL" \
    --skip-phase2-dryrun \
    --modules "$MALICIOUS_MODULES" >"$STDOUT_LOG" 2>"$STDERR_LOG"
)
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  fail "macOS path-check should treat modules payload as data and complete with fake green tools"
fi

if [[ -e "$FLAG_FILE" ]]; then
  fail "macOS path-check should not execute shell content embedded in --modules"
fi

if [[ ! -f "$MODULE_ARGS_LOG" ]]; then
  fail "fake module runner should receive arguments"
fi

if ! rg -Fx -- "--modules" "$MODULE_ARGS_LOG" >/dev/null; then
  fail "macOS path-check should still pass --modules to the nested runner"
fi

if ! rg -Fx -- "$MALICIOUS_MODULES" "$MODULE_ARGS_LOG" >/dev/null; then
  fail "macOS path-check should pass the full modules payload as data to the nested runner"
fi

echo "[PASS] macOS path-check module injection contract passed"
