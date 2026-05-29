#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a active_docs=(
  "docs/ARCHITECTURE.md"
  "docs/reference/INTERFACE_DESIGN_V2.md"
)

declare -a forbidden_patterns=(
  "├── ISSLServerConnection"
  "└─ ISSLServerConnection"
  "└── ISSLServerConnection"
)

if grep -R -n -E -q 'ISSLServerConnection[[:space:]]*=' src; then
  echo "[FAIL] source unexpectedly declares ISSLServerConnection"
  echo "       update this contract if the public interface is intentionally added"
  exit 1
fi

for file in "${active_docs[@]}"; do
  for pattern in "${forbidden_patterns[@]}"; do
    if grep -n -F -q "$pattern" "$file"; then
      echo "[FAIL] active doc still draws nonexistent ISSLServerConnection into the public interface graph: $file"
      echo "       forbidden pattern: $pattern"
      exit 1
    fi
  done
done

echo "[PASS] active interface docs no longer promise nonexistent ISSLServerConnection"
