#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SANDBOX_ROOT="$(mktemp -d "$PROJECT_ROOT/tmp/test_verify_examples_no_bc_XXXXXX")"
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

cat > "$SANDBOX_ROOT/fakebin/bc" <<'EOF_BC'
#!/usr/bin/env bash
echo "bc missing" >&2
exit 127
EOF_BC

chmod +x "$SANDBOX_ROOT/fakebin/fpc" "$SANDBOX_ROOT/fakebin/bc"

STDOUT_JSON="$SANDBOX_ROOT/stdout.json"
STDERR_LOG="$SANDBOX_ROOT/stderr.log"

set +e
(
  cd "$SANDBOX_ROOT"
  PATH="$SANDBOX_ROOT/fakebin:$PATH" \
    bash scripts/verify_examples_compile.sh -f json >"$STDOUT_JSON" 2>"$STDERR_LOG"
)
EXIT_CODE=$?
set -e

if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo "[FAIL] verify_examples_compile should not fail just because bc is unavailable when pass_rate can be computed without it"
  echo "[TRACE] stdout:"
  sed -n '1,120p' "$STDOUT_JSON"
  echo "[TRACE] stderr:"
  sed -n '1,120p' "$STDERR_LOG"
  exit 1
fi

if ! python3 - "$STDOUT_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

summary = data.get("summary", {})
assert summary.get("total") == 1, summary
assert summary.get("passed") == 1, summary
assert summary.get("pass_rate") == 100.0, summary
PY
then
  echo "[FAIL] verify_examples_compile should keep emitting valid json with numeric pass_rate even when bc is unavailable"
  echo "[TRACE] stdout:"
  sed -n '1,120p' "$STDOUT_JSON"
  echo "[TRACE] stderr:"
  sed -n '1,120p' "$STDERR_LOG"
  exit 1
fi

if rg -n "^bc missing$" "$STDERR_LOG" >/dev/null; then
  echo "[FAIL] verify_examples_compile should no longer invoke bc for pass_rate calculation"
  exit 1
fi

echo "[PASS] verify_examples_compile pass-rate no-bc contract passed"
