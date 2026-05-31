#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_ref="docs/reference/API_REFERENCE.md"
api_doc="docs/reference/API_DOCUMENTATION.md"
integration_doc="docs/INTEGRATION_GUIDE.md"
e2e_test="tests/integration/test_e2e_scenarios.pas"

declare -a forbidden_api_ref_patterns=(
  "LSession := LConn1.GetSession;"
  "LConn2.SetSession(LSession);"
  "BoolToStr(LConn2.IsSessionReused, True)"
  "LSession := LConn.GetSession;"
  "LConn.SetSession(LSession)"
  "if not LConn.IsSessionReused then"
)

for pattern in "${forbidden_api_ref_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$api_ref"; then
    echo "[FAIL] API reference still teaches direct core session-resumption usage: $pattern"
    exit 1
  fi
done

declare -a required_api_ref_patterns=(
  "LResumption1, LResumption2: ISSLSessionResumption;"
  "Supports(LConn1, ISSLSessionResumption, LResumption1)"
  "LSession := LResumption1.GetSession;"
  "Supports(LConn2, ISSLSessionResumption, LResumption2)"
  "LResumption2.SetSession(LSession);"
  "BoolToStr(LResumption2.IsSessionReused, True)"
  '优先通过 `ISSLSessionResumption.GetSession`'
  '优先通过 `ISSLSessionResumption.SetSession`'
  '优先通过 `ISSLSessionResumption.IsSessionReused`'
)

for pattern in "${required_api_ref_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$api_ref"; then
    echo "[FAIL] API reference missing ISSLSessionResumption-first guidance: $pattern"
    exit 1
  fi
done

declare -a forbidden_api_doc_patterns=(
  "Session := Connection.GetSession;"
  "Connection.SetSession(Session);"
  "Connection.SetSession(Session)"
)

for pattern in "${forbidden_api_doc_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API documentation still teaches direct core session-resumption usage: $pattern"
    exit 1
  fi
done

declare -a required_api_doc_patterns=(
  "SessionResumption: ISSLSessionResumption;"
  "Supports(Connection, ISSLSessionResumption, SessionResumption)"
  "Session := SessionResumption.GetSession;"
  "SessionResumption.SetSession(Session);"
)

for pattern in "${required_api_doc_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$api_doc"; then
    echo "[FAIL] API documentation missing ISSLSessionResumption-first guidance: $pattern"
    exit 1
  fi
done

if grep -F -q -- "InitialStream.Connection.GetSession;" "$integration_doc"; then
  echo "[FAIL] integration guide still teaches direct core GetSession on resumed-stream path"
  exit 1
fi

declare -a required_integration_patterns=(
  "Resumption: ISSLSessionResumption;"
  "Supports(InitialStream.Connection, ISSLSessionResumption, Resumption)"
  "Session := Resumption.GetSession;"
)

for pattern in "${required_integration_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$integration_doc"; then
    echo "[FAIL] integration guide missing ISSLSessionResumption-first guidance: $pattern"
    exit 1
  fi
done

declare -a forbidden_e2e_patterns=(
  "Sess := Conn1.GetSession;"
  "Conn2.SetSession(Sess);"
  "Runner.Check('Session Resumption - Reused', Conn2.IsSessionReused,"
)

for pattern in "${forbidden_e2e_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$e2e_test"; then
    echo "[FAIL] e2e scenario still uses direct core session-resumption mirror: $pattern"
    exit 1
  fi
done

declare -a required_e2e_patterns=(
  "Resumption1, Resumption2: ISSLSessionResumption;"
  "Supports(Conn1, ISSLSessionResumption, Resumption1)"
  "Sess := Resumption1.GetSession;"
  "Supports(Conn2, ISSLSessionResumption, Resumption2)"
  "Resumption2.SetSession(Sess);"
  "Runner.Check('Session Resumption - Reused', Resumption2.IsSessionReused,"
)

for pattern in "${required_e2e_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$e2e_test"; then
    echo "[FAIL] e2e scenario missing ISSLSessionResumption owner path: $pattern"
    exit 1
  fi
done

echo "[PASS] active docs/tests prefer ISSLSessionResumption for session-resumption surfaces"
