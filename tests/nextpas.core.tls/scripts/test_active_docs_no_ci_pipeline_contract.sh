#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a active_docs=(
  "README.md"
  "docs/guides/GETTING_STARTED.md"
  "docs/guides/QUICKSTART.md"
  "docs/guides/PERFORMANCE_OPTIMIZATION_GUIDE.md"
)

for file in "${active_docs[@]}"; do
  if rg -n --quiet "ci_pipeline\\.sh" "$file"; then
    echo "[FAIL] active doc still references removed ci_pipeline entrypoint: $file"
    rg -n "ci_pipeline\\.sh" "$file" || true
    exit 1
  fi
done

echo "[PASS] active docs no longer reference removed ci_pipeline entrypoint"
