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

mbedtls_matrix="docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md"
mbedtls_guide="docs/guides/MBEDTLS_USER_GUIDE.md"

echo "[TEST] MbedTLS active docs capability truth contract"

require_fixed "$mbedtls_matrix" "| 证书固定 | ✅ 支持 | 使用 context pinning API（AddCertificatePin / SetCertificatePinningEnabled），不是 callback surface |" \
  "MbedTLS matrix must describe pinning through current context APIs instead of callbacks"
require_fixed "$mbedtls_matrix" "| 0-RTT | ❌ 当前 capability 不发布 | 当前 backend 不暴露 ISSLEarlyDataContext / ISSLEarlyDataConnection public surface |" \
  "MbedTLS matrix must stop implying published 0-RTT support"
require_fixed "$mbedtls_matrix" "| 自定义 I/O | ❌ 当前 public callback surface 不发布 | 当前 transport path 仅使用内置 socket/stream BIO wiring，不提供 caller-supplied I/O callback seam |" \
  "MbedTLS matrix must stop implying published custom I/O callbacks"
require_fixed "$mbedtls_matrix" "  fafafa.ssl," \
  "MbedTLS matrix backend identifier example must use the current public facade unit"
require_fixed "$mbedtls_matrix" "  nextpas.core.tls.context.builder;" \
  "MbedTLS matrix backend identifier example must import the current builder entry"
require_fixed "$mbedtls_matrix" ".WithCAFile('/etc/ssl/certs/ca-certificates.crt')" \
  "MbedTLS matrix example should use explicit CA file guidance"
require_absent "$mbedtls_matrix" "| 证书固定 | ✅ 支持 | 通过回调 |" \
  "MbedTLS matrix must stop attributing pinning to callbacks"
require_absent "$mbedtls_matrix" "| 0-RTT | ⚠️ 部分 |" \
  "MbedTLS matrix must stop describing 0-RTT as partially published"
require_absent "$mbedtls_matrix" "| 自定义 I/O | ✅ 支持 | 回调函数 |" \
  "MbedTLS matrix must stop claiming published custom I/O callbacks"
require_absent "$mbedtls_matrix" "uses nextpas.core.tls.base;" \
  "MbedTLS matrix backend identifier example must stop teaching nextpas.core.tls.base"
require_absent "$mbedtls_matrix" ".WithSystemRoots" \
  "MbedTLS matrix example should stop implying system roots as the primary deterministic path"

require_fixed "$mbedtls_guide" 'MbedTLS 与其它 backend 共享统一核心接口，但具体 published capability 仍以后端的 `ISSLLibrary.GetCapabilities` 为准。' \
  "MbedTLS guide must explain backend-specific capability truth"
require_fixed "$mbedtls_guide" '当前 `SupportsCallbacks=False`：verify / password / info callback 的 non-nil assignment 会 fail-closed `unsupported`。' \
  "MbedTLS guide must record callback publication truth"
require_fixed "$mbedtls_guide" '当前 `SupportsFIPSMode=False`：不要把上游 Mbed TLS 的认证/商业版本能力当成 fafafa.ssl 当前 backend truth。' \
  "MbedTLS guide must record current FIPS capability truth"
require_fixed "$mbedtls_guide" '当前不发布 `ISSLEarlyDataContext / ISSLEarlyDataConnection` public surface；0-RTT 应视为 current capability none。' \
  "MbedTLS guide must record current 0-RTT publication truth"
require_fixed "$mbedtls_guide" "Context := Lib.CreateContext(sslCtxClient);" \
  "MbedTLS guide examples must use current context creation signature"
require_fixed "$mbedtls_guide" "Context.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');" \
  "MbedTLS guide examples must use current CA-loading API"
require_fixed "$mbedtls_guide" "if Supports(Connection, ISSLClientConnection, ClientConn) then" \
  "MbedTLS guide must use per-connection SNI access"
require_fixed "$mbedtls_guide" "ClientConn.SetServerName('www.example.com');" \
  "MbedTLS guide must use current server-name setter"
require_fixed "$mbedtls_guide" "WriteLn('连接失败，错误码: ', Lib.GetLastError);" \
  "MbedTLS guide must route connection-failure error codes through ISSLLibrary"
require_fixed "$mbedtls_guide" "WriteLn('连接失败，错误信息: ', Lib.GetLastErrorString);" \
  "MbedTLS guide must route connection-failure error strings through ISSLLibrary"
require_fixed "$mbedtls_guide" "if Connection.ReadString(Response) then" \
  "MbedTLS guide must use current ReadString signature"
require_fixed "$mbedtls_guide" "WriteLn('密码套件: ', Connection.GetCipherName);" \
  "MbedTLS guide must use current cipher-name API"
require_fixed "$mbedtls_guide" '这里只列当前 MbedTLS 指南最常用的 `ISSLConnection` / `ISSLClientConnection` 片段，不是 `v1.5.0` 完整源码镜像；完整签名以 `src/nextpas.core.tls.base.pas` / `docs/reference/API_REFERENCE.md` 为准。' \
  "MbedTLS guide must label its interface summary as a partial current-surface slice"
require_fixed "$mbedtls_guide" "function GetError(ARet: Integer): TSSLErrorCode;" \
  "MbedTLS guide interface summary must expose current ISSLConnection error surface"
require_fixed "$mbedtls_guide" "function GetProtocolVersion: TSSLProtocolVersion;" \
  "MbedTLS guide interface summary must expose current protocol-version enum truth"
require_absent "$mbedtls_guide" "完全相同的接口" \
  "MbedTLS guide must stop claiming identical interfaces"
require_absent "$mbedtls_guide" "Context.LoadCertificateFromFile" \
  "MbedTLS guide must stop using stale certificate loader names"
require_absent "$mbedtls_guide" "Context.LoadPrivateKeyFromFile" \
  "MbedTLS guide must stop using stale private-key loader names"
require_absent "$mbedtls_guide" "Context.LoadCAFromFile" \
  "MbedTLS guide must stop using stale CA loader names"
require_absent "$mbedtls_guide" "Connection.SetHostname" \
  "MbedTLS guide must stop using stale hostname setter"
require_absent "$mbedtls_guide" "Connection.ReadAll" \
  "MbedTLS guide must stop using stale ReadAll helper"
require_absent "$mbedtls_guide" "GetCipherSuite" \
  "MbedTLS guide must stop using stale cipher-suite accessor name"
require_absent "$mbedtls_guide" "Connection.GetLastErrorString" \
  "MbedTLS guide must stop teaching a nonexistent connection-level error-string API"
require_absent "$mbedtls_guide" "GetLastError: string" \
  "MbedTLS guide interface summary must stop exposing stale GetLastError signature"
require_absent "$mbedtls_guide" "function GetProtocolVersion: string;" \
  "MbedTLS guide interface summary must stop treating protocol version as string"
require_absent "$mbedtls_guide" "function GetLastErrorString: string;" \
  "MbedTLS guide interface summary must stop inventing connection-level error strings"

echo "[PASS] MbedTLS active docs capability truth contract passed"
