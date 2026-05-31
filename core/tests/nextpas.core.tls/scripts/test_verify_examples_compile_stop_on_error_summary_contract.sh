#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SANDBOX_ROOT="$(mktemp -d "$PROJECT_ROOT/tmp/test_verify_examples_stop_on_error_XXXXXX")"
trap 'rm -rf "$SANDBOX_ROOT"' EXIT

mkdir -p \
  "$SANDBOX_ROOT/scripts" \
  "$SANDBOX_ROOT/examples" \
  "$SANDBOX_ROOT/src" \
  "$SANDBOX_ROOT/fakebin"

cp "$PROJECT_ROOT/scripts/verify_examples_compile.sh" "$SANDBOX_ROOT/scripts/"

cat > "$SANDBOX_ROOT/examples/01_ok.pas" <<'EOF_OK'
program example_ok;
begin
end.
EOF_OK

cat > "$SANDBOX_ROOT/examples/02_fail.pas" <<'EOF_FAIL'
program example_fail;
begin
end.
EOF_FAIL

cat > "$SANDBOX_ROOT/examples/03_later.pas" <<'EOF_LATER'
program example_later;
begin
end.
EOF_LATER

cat > "$SANDBOX_ROOT/fakebin/fpc" <<'EOF_FPC'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-iV" ]]; then
  echo "3.2.2"
  exit 0
fi

target="${*: -1}"
if [[ "$target" == *"/02_fail.pas" ]]; then
  exit 1
fi

exit 0
EOF_FPC
chmod +x "$SANDBOX_ROOT/fakebin/fpc"

STDOUT_JSON="$SANDBOX_ROOT/stdout.json"
STDERR_LOG="$SANDBOX_ROOT/stderr.log"

set +e
(
  cd "$SANDBOX_ROOT"
  PATH="$SANDBOX_ROOT/fakebin:$PATH" \
    bash scripts/verify_examples_compile.sh -s -f json >"$STDOUT_JSON" 2>"$STDERR_LOG"
)
EXIT_CODE=$?
set -e

if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo "[FAIL] stop-on-error scenario should still return non-zero after the first failed example"
  exit 1
fi

if ! python3 - "$STDOUT_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

summary = data.get("summary", {})
assert summary.get("total") == 3, summary
assert summary.get("tested") == 2, summary
assert summary.get("passed") == 1, summary
assert summary.get("failed") == 1, summary
assert summary.get("skipped") == 0, summary
assert summary.get("remaining") == 1, summary
assert summary.get("stopped_early") is True, summary
PY
then
  echo "[FAIL] stop-on-error json summary should expose full total plus tested/remaining/stopped_early truth"
  echo "[TRACE] stdout:"
  sed -n '1,120p' "$STDOUT_JSON"
  echo "[TRACE] stderr:"
  sed -n '1,120p' "$STDERR_LOG"
  exit 1
fi

echo "[PASS] verify_examples_compile stop-on-error summary truth contract passed"
