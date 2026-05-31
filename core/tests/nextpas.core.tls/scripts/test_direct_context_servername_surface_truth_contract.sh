#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"

if ! rg -n --quiet "deprecated 'Use per-connection SNI via ISSLClientConnection\\.SetServerName';" "$base_file"; then
  echo "[FAIL] ISSLContext.SetServerName no longer carries the expected per-connection deprecation message"
  exit 1
fi

if ! rg -n --quiet "deprecated 'Use per-connection SNI via ISSLClientConnection\\.GetServerName';" "$base_file"; then
  echo "[FAIL] ISSLContext.GetServerName no longer carries the expected per-connection deprecation message"
  exit 1
fi

if ! rg -F -n --quiet '`ISSLContext.SetServerName(...)` / `GetServerName(...)` 仍保留为 deprecated direct context compatibility API' "$api_ref"; then
  echo "[FAIL] API reference no longer classifies direct ISSLContext ServerName APIs as deprecated compatibility-only"
  exit 1
fi

mapfile -t active_doc_hits < <(
  rg -l 'ISSLContext\.(SetServerName|GetServerName)\(' \
    docs/README.md docs/guides docs/reference docs/ARCHITECTURE.md docs/INTEGRATION_GUIDE.md docs/ZERO_DEPENDENCY_DEPLOYMENT.md || true
)

for file in "${active_doc_hits[@]}"; do
  if [[ "$file" != "$api_ref" ]]; then
    echo "[FAIL] active doc unexpectedly names direct ISSLContext ServerName APIs outside API reference: $file"
    rg -n 'ISSLContext\.(SetServerName|GetServerName)\(' "$file" || true
    exit 1
  fi
done

if rg -n '\b(AContext|FContext|Ctx|LCtx|LContext|Context)[0-9]*\.(SetServerName|GetServerName)\(' src \
  | rg -v '^[0-9]+:\s*(procedure|function)\s+' >/dev/null; then
  echo "[FAIL] production source reintroduced a direct context ServerName caller"
  rg -n '\b(AContext|FContext|Ctx|LCtx|LContext|Context)[0-9]*\.(SetServerName|GetServerName)\(' src \
    | rg -v '^[0-9]+:\s*(procedure|function)\s+' || true
  exit 1
fi

if rg -n '\b(Ctx|Context|LCtx|LContext|ClientCtx)\.SetServerName\(' \
  docs/README.md docs/guides docs/reference docs/ARCHITECTURE.md docs/INTEGRATION_GUIDE.md docs/ZERO_DEPENDENCY_DEPLOYMENT.md >/dev/null; then
  echo "[FAIL] active docs reintroduced direct context ServerName guidance"
  rg -n '\b(Ctx|Context|LCtx|LContext|ClientCtx)\.SetServerName\(' \
    docs/README.md docs/guides docs/reference docs/ARCHITECTURE.md docs/INTEGRATION_GUIDE.md docs/ZERO_DEPENDENCY_DEPLOYMENT.md || true
  exit 1
fi

echo "[PASS] direct ISSLContext ServerName APIs stay frozen as a deprecated compatibility-only surface"
