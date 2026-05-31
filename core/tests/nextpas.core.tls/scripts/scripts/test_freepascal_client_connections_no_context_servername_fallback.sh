#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

TARGET="src/nextpas.core.tls.freepascal.connection.pas"

if grep -n -q 'GetContextLevelServerNameCompatibilityValue(AContext)' "$TARGET"; then
  echo "[FAIL] FreePascal client connection constructors still read context-level ServerName compatibility fallback"
  grep -n 'GetContextLevelServerNameCompatibilityValue(AContext)' "$TARGET" || true
  exit 1
fi

echo "[PASS] FreePascal client connection constructors no longer read context-level ServerName compatibility fallback"
