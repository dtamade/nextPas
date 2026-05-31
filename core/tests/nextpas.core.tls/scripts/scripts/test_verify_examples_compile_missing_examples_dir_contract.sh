#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SANDBOX_ROOT="$(mktemp -d "$PROJECT_ROOT/tmp/test_verify_examples_missing_dir_XXXXXX")"
trap 'rm -rf "$SANDBOX_ROOT"' EXIT

mkdir -p \
  "$SANDBOX_ROOT/scripts" \
  "$SANDBOX_ROOT/src" \
  "$SANDBOX_ROOT/fakebin"

cp "$PROJECT_ROOT/scripts/verify_examples_compile.sh" "$SANDBOX_ROOT/scripts/"

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

set +e
(
  cd "$SANDBOX_ROOT"
  PATH="$SANDBOX_ROOT/fakebin:$PATH" \
    bash scripts/verify_examples_compile.sh -f json >"$STDOUT_JSON" 2>"$STDERR_LOG"
)
EXIT_CODE=$?
set -e

if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo "[FAIL] verify_examples_compile should fail loudly when the examples directory is missing"
  echo "[TRACE] stdout:"
  sed -n '1,120p' "$STDOUT_JSON"
  echo "[TRACE] stderr:"
  sed -n '1,120p' "$STDERR_LOG"
  exit 1
fi

if ! rg -n "examples.目录|examples directory|无法扫描|不存在" "$STDERR_LOG" >/dev/null; then
  echo "[FAIL] verify_examples_compile should explain that the examples directory is missing or unreadable"
  exit 1
fi

if python3 - "$STDOUT_JSON" 2>/dev/null <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    json.load(f)
PY
then
  echo "[FAIL] verify_examples_compile should not emit a success-like json summary when examples directory scanning never succeeded"
  exit 1
fi

echo "[PASS] verify_examples_compile missing examples directory contract passed"
