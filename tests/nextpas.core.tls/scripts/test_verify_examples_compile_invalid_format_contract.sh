#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SANDBOX_ROOT="$(mktemp -d "$PROJECT_ROOT/tmp/test_verify_examples_invalid_format_XXXXXX")"
trap 'rm -rf "$SANDBOX_ROOT"' EXIT

mkdir -p \
  "$SANDBOX_ROOT/scripts" \
  "$SANDBOX_ROOT/examples" \
  "$SANDBOX_ROOT/src" \
  "$SANDBOX_ROOT/fakebin"

cp "$PROJECT_ROOT/scripts/verify_examples_compile.sh" "$SANDBOX_ROOT/scripts/"

cat > "$SANDBOX_ROOT/examples/example_ok.pas" <<'EOF_PAS'
program example_ok;
begin
end.
EOF_PAS

cat > "$SANDBOX_ROOT/fakebin/fpc" <<'EOF_FPC'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-iV" ]]; then
  echo "3.2.2"
  exit 0
fi

exit 0
EOF_FPC

chmod +x "$SANDBOX_ROOT/fakebin/fpc"

STDOUT_LOG="$SANDBOX_ROOT/stdout.log"
STDERR_LOG="$SANDBOX_ROOT/stderr.log"

set +e
(
  cd "$SANDBOX_ROOT"
  PATH="$SANDBOX_ROOT/fakebin:$PATH" \
    bash scripts/verify_examples_compile.sh -f yaml >"$STDOUT_LOG" 2>"$STDERR_LOG"
)
EXIT_CODE=$?
set -e

if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo "[FAIL] verify_examples_compile should reject unsupported output formats instead of silently falling back to text"
  echo "[TRACE] stdout:"
  sed -n '1,120p' "$STDOUT_LOG"
  echo "[TRACE] stderr:"
  sed -n '1,120p' "$STDERR_LOG"
  exit 1
fi

if ! rg -n "不支持的输出格式|invalid format|输出格式" "$STDERR_LOG" >/dev/null; then
  echo "[FAIL] verify_examples_compile should explain unsupported formats on stderr"
  exit 1
fi

if rg -n "编译验证摘要" "$STDOUT_LOG" >/dev/null; then
  echo "[FAIL] verify_examples_compile should not silently emit a text summary for an unsupported format"
  exit 1
fi

echo "[PASS] verify_examples_compile invalid format contract passed"
