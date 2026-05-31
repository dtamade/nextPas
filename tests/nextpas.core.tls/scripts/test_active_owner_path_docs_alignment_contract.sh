#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

api_ref="docs/reference/API_REFERENCE.md"
winssl_best="docs/guides/WINSSL_BEST_PRACTICES.md"
profiling_guide="docs/guides/PERFORMANCE_PROFILING_GUIDE.md"
winssl_design="docs/reference/WINSSL_DESIGN.md"

echo "[TEST] active owner-path docs alignment contract"

require_fixed "$api_ref" '- 通过 `ISSLDiagnostics.GetHealthStatus` 获取连接健康状态' \
  "API reference must describe TSSLHealthStatus via ISSLDiagnostics owner path"
require_fixed "$api_ref" '- 通过 `ISSLDiagnostics.GetPerformanceMetrics` 获取性能指标' \
  "API reference must describe TSSLPerformanceMetrics via ISSLDiagnostics owner path"
require_fixed "$api_ref" '- 通过 `ISSLDiagnostics.GetDiagnosticInfo` 获取完整诊断信息' \
  "API reference must describe TSSLDiagnosticInfo via ISSLDiagnostics owner path"
require_absent "$api_ref" '- 通过 `ISSLConnection.GetHealthStatus` 获取连接健康状态' \
  "API reference must stop teaching direct-core GetHealthStatus as the default entry"
require_absent "$api_ref" '- 通过 `ISSLConnection.GetPerformanceMetrics` 获取性能指标' \
  "API reference must stop teaching direct-core GetPerformanceMetrics as the default entry"
require_absent "$api_ref" '- 通过 `ISSLConnection.GetDiagnosticInfo` 获取完整诊断信息' \
  "API reference must stop teaching direct-core GetDiagnosticInfo as the default entry"

require_fixed "$winssl_best" 'Supports(LConn1, ISSLSessionResumption, LResumption1)' \
  "WinSSL best-practices guide must expose ISSLSessionResumption on the first connection"
require_fixed "$winssl_best" 'LSession := LResumption1.GetSession;' \
  "WinSSL best-practices guide must save sessions through ISSLSessionResumption"
require_fixed "$winssl_best" 'Supports(LConn, ISSLSessionResumption, LResumption)' \
  "WinSSL best-practices guide must expose ISSLSessionResumption on resumed connections"
require_fixed "$winssl_best" 'LResumption.SetSession(LSession);' \
  "WinSSL best-practices guide must restore sessions through ISSLSessionResumption"
require_absent "$winssl_best" 'LSession := LConn1.GetSession;' \
  "WinSSL best-practices guide must stop teaching direct-core GetSession"
require_absent "$winssl_best" 'LConn.SetSession(LSession);' \
  "WinSSL best-practices guide must stop teaching direct-core SetSession"

require_fixed "$profiling_guide" 'Supports(Conn1, ISSLSessionResumption, Resumption1)' \
  "Performance profiling guide must expose ISSLSessionResumption on the first connection"
require_fixed "$profiling_guide" 'Session := Resumption1.GetSession;' \
  "Performance profiling guide must save sessions through ISSLSessionResumption"
require_fixed "$profiling_guide" 'Supports(Conn2, ISSLSessionResumption, Resumption2)' \
  "Performance profiling guide must expose ISSLSessionResumption on the second connection"
require_fixed "$profiling_guide" 'Resumption2.SetSession(Session);' \
  "Performance profiling guide must restore sessions through ISSLSessionResumption"
require_absent "$profiling_guide" 'Session := Conn1.GetSession;' \
  "Performance profiling guide must stop teaching direct-core GetSession"
require_absent "$profiling_guide" 'Conn2.SetSession(Session);' \
  "Performance profiling guide must stop teaching direct-core SetSession"

require_fixed "$winssl_design" 'Supports(LConn, ISSLSessionResumption, LResumption)' \
  "WinSSL design doc must expose ISSLSessionResumption in warmup pseudocode"
require_fixed "$winssl_design" 'FSessionManager.AddSession(LHost, LResumption.GetSession);' \
  "WinSSL design doc must store warmup sessions through ISSLSessionResumption"
require_absent "$winssl_design" 'FSessionManager.AddSession(LHost, LConn.GetSession);' \
  "WinSSL design doc must stop teaching direct-core GetSession"

echo "[PASS] active owner-path docs alignment contract passed"
