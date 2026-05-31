#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

TARGET="tests/test_tls_connector_hostname_override_precedence.pas"

if grep -n -q 'Ctx\.SetServerName(' "$TARGET"; then
  echo "[FAIL] TLS connector override precedence test still teaches context-level SNI"
  grep -n 'Ctx\.SetServerName(' "$TARGET" || true
  exit 1
fi

echo "[PASS] TLS connector override precedence test no longer teaches context-level SNI"
