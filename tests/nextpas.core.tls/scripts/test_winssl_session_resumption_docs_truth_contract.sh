#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

matrix_doc="$ROOT_DIR/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
perf_doc="$ROOT_DIR/docs/reference/WINSSL_PERFORMANCE_TUNING.md"
api_ref="$ROOT_DIR/docs/reference/API_REFERENCE.md"
status_report="$ROOT_DIR/docs/test_reports/WINSSL_BACKEND_STATUS_REPORT.md"
top_matrix="$ROOT_DIR/docs/BACKEND_CAPABILITY_MATRIX.md"
quickstart_doc="$ROOT_DIR/docs/guides/QUICKSTART.md"
design_doc="$ROOT_DIR/docs/reference/WINSSL_DESIGN.md"
abstraction_doc="$ROOT_DIR/docs/reference/BACKEND_ABSTRACTION_LAYER_DESIGN.md"
selector_doc="$ROOT_DIR/docs/reference/BACKEND_SELECTOR_DESIGN.md"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] WinSSL session-resumption docs truth contract"

for pattern in \
  "Session 复用 | ✅ 支持 | 完整支持" \
  "Session Ticket | ✅ 支持 | TLS 1.2+" \
  "Conn1.GetSession" \
  "Conn2.SetSession(Session)" \
  "Conn2.IsSessionResumed"
do
  if grep -F -q -- "$pattern" "$matrix_doc"; then
    fail "WinSSL backend capability matrix still overclaims or uses stale session-resumption guidance: $pattern"
  fi
done

for pattern in \
  "| **Session Resumption**       | ✅         | ✅      | ✅     | ✅      | ✅      |"
do
  if grep -F -q -- "$pattern" "$top_matrix"; then
    fail "Top-level backend capability matrix still overclaims session resumption truth: $pattern"
  fi
done

for pattern in \
  "| **Session Resumption**       | ⚠️         | ✅      | ⚠️     | ⚠️      | ✅      |" \
  "observed_reuse=false" \
  "session_configured=true"
do
  if ! grep -F -q -- "$pattern" "$top_matrix"; then
    fail "Top-level backend capability matrix missing current session-resumption truth: $pattern"
  fi
done

for pattern in \
  "ISSLSessionResumption" \
  "observed_reuse=false" \
  "session_configured=true"
do
  if ! grep -F -q -- "$pattern" "$matrix_doc"; then
    fail "WinSSL backend capability matrix missing current session-resumption truth: $pattern"
  fi
done

for pattern in \
  "可显著提升连接性能（70-90%）" \
  "✓ Session 复用成功 - 握手时间大幅减少" \
  "Session 复用可减少 70-90% 的握手时间"
do
  if grep -F -q -- "$pattern" "$quickstart_doc"; then
    fail "Quickstart still overclaims WinSSL session-resumption success/performance: $pattern"
  fi
done

for pattern in \
  "ISSLSessionResumption" \
  "observed_reuse=false" \
  "session_configured=true"
do
  if ! grep -F -q -- "$pattern" "$quickstart_doc"; then
    fail "Quickstart missing current WinSSL runtime caution: $pattern"
  fi
done

for pattern in \
  "5. 调用 QueryContextAttributes(SECPKG_ATTR_SESSION_INFO) 获取 Session 信息" \
  "function GetSessionInfo: SecPkgContext_SessionInfo;" \
  "| **性能提升**     | 70-90%               | 70-90%               |"
do
  if grep -F -q -- "$pattern" "$design_doc"; then
    fail "WinSSL design doc still presents native session-info or performance as settled production truth: $pattern"
  fi
done

for pattern in \
  "opt-in isolated worker / experimental evidence lane" \
  "observed_reuse=false" \
  "session_configured=true"
do
  if ! grep -F -q -- "$pattern" "$design_doc"; then
    fail "WinSSL design doc missing current runtime/native-probe boundary truth: $pattern"
  fi
done

for pattern in \
  "| OCSP Stapling | ✅ | ❌ | ✅ |" \
  "| Session Ticket | ✅ | ✅ | ✅ |"
do
  if grep -F -q -- "$pattern" "$abstraction_doc"; then
    fail "Backend abstraction design still overclaims WinSSL capability truth: $pattern"
  fi
done

# Abstraction doc now delegates per-feature truth to the canonical matrix;
# no per-feature table rows to assert here.

for pattern in \
  "| OCSP Stapling | ✅ | ✅ | ❌ |" \
  "| Session Ticket | ✅ | ✅ | ✅ |"
do
  if grep -F -q -- "$pattern" "$selector_doc"; then
    fail "Backend selector design still overclaims WinSSL requirement support: $pattern"
  fi
done

# Selector doc now delegates per-feature truth to the canonical matrix;
# no per-feature table rows to assert here.

for pattern in \
  "减少握手时间 70-90%" \
  "Result.SessionReused := AConn.IsSessionResumed;" \
  "LSession := LConn.GetSession;" \
  "LConn2.IsSessionResumed" \
  "快速握手" \
  "性能提升"
do
  if grep -F -q -- "$pattern" "$perf_doc"; then
    fail "WinSSL performance tuning guide still overclaims runtime-proven session resumption: $pattern"
  fi
done

for pattern in \
  "ISSLSessionResumption" \
  "observed_reuse=false" \
  "当前 dedicated Windows CI runtime truth"
do
  if ! grep -F -q -- "$pattern" "$perf_doc"; then
    fail "WinSSL performance tuning guide missing current runtime caution: $pattern"
  fi
done

for pattern in \
  "✓ Session 复用成功 - 握手时间大幅减少"
do
  if grep -F -q -- "$pattern" "$api_ref"; then
    fail "API reference still presents WinSSL session resumption as a stable success path: $pattern"
  fi
done

for pattern in \
  "| 性能提升       | 70-90%               | 70-90%             |"
do
  if grep -F -q -- "$pattern" "$api_ref"; then
    fail "API reference still overclaims WinSSL session-resumption performance truth: $pattern"
  fi
done

for pattern in \
  "observed_reuse=false" \
  "session_configured=true" \
  "26037518301"
do
  if ! grep -F -q -- "$pattern" "$api_ref"; then
    fail "API reference missing current WinSSL runtime truth note: $pattern"
  fi
done

for pattern in \
  "26037518301" \
  "observed_reuse=false" \
  "session_configured=true" \
  "windows-gate"
do
  if ! grep -F -q -- "$pattern" "$status_report"; then
    fail "WinSSL backend status report missing final green runtime bridge truth: $pattern"
  fi
done

echo "[PASS] WinSSL session-resumption docs truth contract passed"
