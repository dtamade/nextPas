#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_REL="tmp/test_macos_openssl_path_check_openssl_root_injection_$(date +%s)"
WORK_DIR="$ROOT_DIR/$WORK_REL"
FAKE_ROOT="$WORK_DIR/fake_project"
FAKE_SCRIPTS="$FAKE_ROOT/scripts"
FAKE_BIN="$WORK_DIR/fake_bin"
FLAG_FILE="$WORK_DIR/openssl_root_injected.flag"
OPENSSL_ENV_LOG="$WORK_DIR/openssl_root_env.log"
STDOUT_LOG="$WORK_DIR/stdout.log"
STDERR_LOG="$WORK_DIR/stderr.log"
MALICIOUS_OPENSSL_ROOT="$WORK_DIR/openssl'; touch '$FLAG_FILE'; echo '"

mkdir -p "$FAKE_SCRIPTS" "$FAKE_BIN" "$MALICIOUS_OPENSSL_ROOT/lib" "$MALICIOUS_OPENSSL_ROOT/include/openssl" "$MALICIOUS_OPENSSL_ROOT/bin"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  echo "[FAIL] $1"
  exit 1
}

: > "$MALICIOUS_OPENSSL_ROOT/lib/libcrypto.dylib"
: > "$MALICIOUS_OPENSSL_ROOT/lib/libssl.dylib"
: > "$MALICIOUS_OPENSSL_ROOT/include/openssl/ssl.h"

cp "$ROOT_DIR/scripts/run_macos_openssl_path_check_draft.sh" "$FAKE_SCRIPTS/"

cat > "$MALICIOUS_OPENSSL_ROOT/bin/openssl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${OPENSSL_ROOT:-}" > "${OPENSSL_ENV_LOG:?}"
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
exit 0
EOF

cat > "$FAKE_SCRIPTS/run_phase2_performance_baseline.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

chmod +x "$MALICIOUS_OPENSSL_ROOT/bin/openssl" "$FAKE_BIN/fpc" "$FAKE_SCRIPTS/"*.sh

set +e
(
  cd "$FAKE_ROOT"
  PATH="$FAKE_BIN:$PATH" \
  OPENSSL_ENV_LOG="$OPENSSL_ENV_LOG" \
  OSTYPE=darwin23 \
  bash scripts/run_macos_openssl_path_check_draft.sh \
    --openssl-root "$MALICIOUS_OPENSSL_ROOT" \
    --skip-module-tests \
    --skip-phase2-dryrun >"$STDOUT_LOG" 2>"$STDERR_LOG"
)
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  fail "macOS path-check should treat openssl-root payload as data and complete with fake green tools"
fi

if [[ -e "$FLAG_FILE" ]]; then
  fail "macOS path-check should not execute shell content embedded in --openssl-root"
fi

if [[ ! -f "$OPENSSL_ENV_LOG" ]]; then
  fail "fake openssl should observe OPENSSL_ROOT env"
fi

if ! rg -Fx -- "$MALICIOUS_OPENSSL_ROOT" "$OPENSSL_ENV_LOG" >/dev/null; then
  fail "macOS path-check should pass the full openssl-root payload as env data"
fi

echo "[PASS] macOS path-check openssl-root injection contract passed"
