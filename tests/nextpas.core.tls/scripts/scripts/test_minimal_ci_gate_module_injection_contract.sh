#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_minimal_ci_gate.sh"
TMP_ROOT="$ROOT_DIR/tmp/contract_minimal_ci_gate_module_injection"
FAKE_BIN="$TMP_ROOT/fakebin"
FLAG_FILE="$TMP_ROOT/injected.flag"
FAKE_BASH_LOG="$TMP_ROOT/fake_bash.log"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] minimal ci gate must treat --modules as data, not shell syntax"

rm -rf "$TMP_ROOT"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/bash" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" >> "${FAFAFA_FAKE_BASH_LOG:?}"
exit 0
EOF
chmod +x "$FAKE_BIN/bash"

if rg -n --quiet '(^|[^[:alnum:]_])eval[[:space:]]' "$SCRIPT"; then
  fail "minimal ci gate should not rely on eval"
fi

set +e
output="$(
  cd "$ROOT_DIR"
  PATH="$FAKE_BIN:$PATH" \
  FAFAFA_FAKE_BASH_LOG="$FAKE_BASH_LOG" \
  /usr/bin/bash "$SCRIPT" --skip-compile --skip-phase2-dryrun --modules "PKCS7; touch '$FLAG_FILE'" 2>&1
)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  printf '%s\n' "$output"
  fail "minimal ci gate contract should exit 0 with fake nested runners"
fi

if [[ -e "$FLAG_FILE" ]]; then
  printf '%s\n' "$output"
  fail "module argument was executed as shell syntax"
fi

if [[ ! -f "$FAKE_BASH_LOG" ]]; then
  printf '%s\n' "$output"
  fail "fake nested bash should have been invoked"
fi

if ! rg -F --quiet -- "--modules" "$FAKE_BASH_LOG"; then
  cat "$FAKE_BASH_LOG"
  fail "module step should still pass --modules to nested runner"
fi

echo "[PASS] minimal ci gate module injection contract passed"
