#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

if [[ ! -f "docs/INTEGRATION_GUIDE.md" ]]; then
  echo "[FAIL] missing docs/INTEGRATION_GUIDE.md (referenced by docs/README.md)"
  exit 1
fi

echo "[PASS] docs/INTEGRATION_GUIDE.md exists"

