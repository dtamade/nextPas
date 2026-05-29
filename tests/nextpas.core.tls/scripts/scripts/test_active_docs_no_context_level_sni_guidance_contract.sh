#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "docs/CA_CERTIFICATE_AUTO_LOADING.md"
  "docs/ZERO_DEPENDENCY_DEPLOYMENT.md"
)

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] active doc still teaches deprecated context-level SNI: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] active docs no longer teach deprecated context-level SNI"
