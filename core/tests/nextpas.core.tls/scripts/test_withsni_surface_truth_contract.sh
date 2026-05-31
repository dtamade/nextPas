#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

builder_file="src/nextpas.core.tls.context.builder.pas"
api_ref="docs/reference/API_REFERENCE.md"

if ! rg -n --quiet 'Compatibility-only context-level SNI\.' "$builder_file"; then
  echo "[FAIL] WithSNI source comment no longer states compatibility-only context-level SNI"
  exit 1
fi

count=$(rg -n 'WithSNI\(' "$builder_file" | wc -l | tr -d ' ')
if [[ "$count" != "3" ]]; then
  echo "[FAIL] unexpected number of WithSNI source hits in $builder_file: $count"
  exit 1
fi

if ! rg -F -n --quiet '`TSSLContextBuilder.WithSNI(...)` 也仍然保留为 compatibility-only 入口；它现在已经是编译期 `deprecated`，且 `BuildClient` / `BuildServer` 都会发出 warning 并忽略它。' "$api_ref"; then
  echo "[FAIL] API reference no longer records the current WithSNI compatibility-only truth"
  exit 1
fi

mapfile -t active_doc_hits < <(
  rg -l 'WithSNI\(' docs/README.md docs/guides docs/reference docs/ARCHITECTURE.md docs/INTEGRATION_GUIDE.md docs/ZERO_DEPENDENCY_DEPLOYMENT.md || true
)

for file in "${active_doc_hits[@]}"; do
  if [[ "$file" != "$api_ref" ]]; then
    echo "[FAIL] active doc unexpectedly teaches WithSNI outside API reference: $file"
    rg -n 'WithSNI\(' "$file" || true
    exit 1
  fi
done

echo "[PASS] WithSNI stays frozen as a deprecated compatibility-only fluent surface"
