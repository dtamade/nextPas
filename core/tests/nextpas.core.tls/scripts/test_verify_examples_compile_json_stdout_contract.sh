#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SANDBOX_ROOT="$(mktemp -d "$PROJECT_ROOT/tmp/test_verify_examples_json_stdout_XXXXXX")"
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

STDOUT_JSON="$SANDBOX_ROOT/stdout.json"
STDERR_LOG="$SANDBOX_ROOT/stderr.log"

(
  cd "$SANDBOX_ROOT"
  PATH="$SANDBOX_ROOT/fakebin:$PATH" \
    bash scripts/verify_examples_compile.sh -f json >"$STDOUT_JSON" 2>"$STDERR_LOG"
)

if ! python3 - "$STDOUT_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

summary = data.get("summary", {})
assert summary.get("total") == 1, summary
assert summary.get("passed") == 1, summary
assert summary.get("failed") == 0, summary
assert summary.get("skipped") == 0, summary
PY
then
  echo "[FAIL] verify_examples_compile -f json should emit parseable JSON to stdout"
  echo "[TRACE] stdout:"
  sed -n '1,80p' "$STDOUT_JSON"
  echo "[TRACE] stderr:"
  sed -n '1,80p' "$STDERR_LOG"
  exit 1
fi

if ! rg -n "FPC 版本|开始编译验证|\\[PASS\\]" "$STDERR_LOG" >/dev/null; then
  echo "[FAIL] expected runtime banner/progress to stay available on stderr when stdout is reserved for JSON"
  exit 1
fi

echo "[PASS] verify_examples_compile json stdout contract passed"
