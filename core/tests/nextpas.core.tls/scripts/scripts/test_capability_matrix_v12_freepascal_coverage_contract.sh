#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

test_file="tests/test_capability_matrix_v12.pas"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local pattern="$1"
  local message="$2"
  if ! rg -F -n --quiet -- "$pattern" "$test_file"; then
    fail "$message"
  fi
}

echo "[TEST] capability matrix v1.2 FreePascal coverage contract"

require_fixed "TestBackendCapabilities('FreePascal', sslFreePascal);" \
  "Capability matrix v1.2 regression must execute the FreePascal backend"

python3 - "$test_file" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
calls = re.findall(r"TestBackendCapabilities\('([^']+)',\s*(ssl[A-Za-z0-9_]+)\);", text)
actual = set(calls)
expected = {
    ("OpenSSL", "sslOpenSSL"),
    ("FreePascal", "sslFreePascal"),
    ("WolfSSL", "sslWolfSSL"),
    ("MbedTLS", "sslMbedTLS"),
    ("WinSSL", "sslWinSSL"),
}

if actual != expected:
    print("[FAIL] capability matrix v1.2 backend call set drifted")
    print("  actual  =", sorted(actual))
    print("  expected=", sorted(expected))
    raise SystemExit(1)

print("[PASS] capability matrix v1.2 backend call set covers the expected 5 backends")
PY
