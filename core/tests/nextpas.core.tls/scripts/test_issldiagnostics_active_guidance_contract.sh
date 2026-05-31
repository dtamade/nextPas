#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_doc="docs/reference/API_REFERENCE.md"
generic_test="tests/test_sslctxboth_roleless_handshake_clarification.pas"

declare -a forbidden_api_patterns=(
  "if LConn.IsHealthy then"
  "LHealth := LConn.GetHealthStatus;"
  "LPerf := LConn.GetPerformanceMetrics;"
  "LDiag := LConn.GetDiagnosticInfo;"
  "if not LConn.IsHealthy then"
)

for pattern in "${forbidden_api_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API reference still teaches direct core diagnostics usage: $pattern"
    exit 1
  fi
done

declare -a required_api_patterns=(
  "if LConn.Connect and Supports(LConn, ISSLDiagnostics, LDiag) then"
  "if LDiag.IsHealthy then"
  "LHealth := LDiag.GetHealthStatus;"
  "LPerf := LDiag.GetPerformanceMetrics;"
  "LDiag := LDiagExt.GetDiagnosticInfo;"
  "优先通过 \`ISSLDiagnostics.GetHealthStatus\`"
  "优先通过 \`ISSLDiagnostics.GetPerformanceMetrics\`"
  "优先通过 \`ISSLDiagnostics.GetDiagnosticInfo\`"
)

for pattern in "${required_api_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API reference missing ISSLDiagnostics-first guidance: $pattern"
    exit 1
  fi
done

if grep -F -q -- "LHealth := LConn.GetHealthStatus;" "$generic_test"; then
  echo "[FAIL] generic dual-context boundary test still uses direct core GetHealthStatus"
  exit 1
fi

declare -a required_generic_patterns=(
  "Supports(LConn, ISSLDiagnostics, LDiag)"
  "LHealth := LDiag.GetHealthStatus;"
)

for pattern in "${required_generic_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$generic_test"; then
    echo "[FAIL] generic dual-context boundary test missing ISSLDiagnostics owner path: $pattern"
    exit 1
  fi
done

echo "[PASS] active docs/tests prefer ISSLDiagnostics for diagnostics surfaces"
