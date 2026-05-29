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

api_doc="docs/reference/API_DOCUMENTATION.md"
winssl_practices="docs/guides/WINSSL_BEST_PRACTICES.md"
winssl_guide="docs/guides/WINSSL_USER_GUIDE.md"

echo "[TEST] active connection API docs truth contract"

require_fixed "$api_doc" "**版本:** rolling" \
  "API_DOCUMENTATION must declare rolling doc version instead of stale 2.0.0 snapshot"
require_fixed "$api_doc" "  fafafa.ssl," \
  "API_DOCUMENTATION must use the current public facade import in active examples"
require_fixed "$api_doc" "  nextpas.core.tls.context.builder;" \
  "API_DOCUMENTATION must keep the builder unit import where ISSLContextBuilder is referenced"
require_fixed "$api_doc" ".WithSystemRoots;" \
  "API_DOCUMENTATION quick-start must use current builder system-roots method"
require_fixed "$api_doc" '下面这段 `5 分钟上手` 展示的是 active API reference 的 direct `ISSLConnection` / owner-surface reference，不是普通新代码唯一推荐的 TLS bootstrap 入口。' \
  "API_DOCUMENTATION quick-start must classify itself as a direct low-level reference path"
require_fixed "$api_doc" '如果你只是普通客户端/服务端接入，优先回到 `docs/guides/GETTING_STARTED.md` 里的 `TSSLConnector` / `TSSLAcceptor` / `TSSLStream` 主路径。' \
  "API_DOCUMENTATION quick-start must route ordinary bootstrap flows back to GETTING_STARTED main entry"
require_fixed "$api_doc" '这里之所以仍直接展示 `CreateConnection(...)`，是因为本页后续还会继续展开挂在连接对象上的 owner surface，例如 `ISSLOCSPStapling` / `ISSLCertificateVerification`。' \
  "API_DOCUMENTATION quick-start must explain why it intentionally stays on the connection owner path"
require_fixed "$api_doc" "Connection := Context.CreateConnection(Socket);" \
  "API_DOCUMENTATION must create SSL connections from caller-owned socket/stream handles"
require_fixed "$api_doc" "if Supports(Connection, ISSLClientConnection, ClientConn) then" \
  "API_DOCUMENTATION quick-start must use per-connection client role surface"
require_fixed "$api_doc" "ClientConn.SetServerName('example.com');" \
  "API_DOCUMENTATION quick-start must set SNI through ISSLClientConnection"
require_fixed "$api_doc" "if Connection.Connect then" \
  "API_DOCUMENTATION must use the current zero-argument Connect signature"
require_fixed "$api_doc" "Connection.WriteString('GET / HTTP/1.1'#13#10 +" \
  "API_DOCUMENTATION quick-start must use the current string convenience writer"
require_fixed "$api_doc" "Connection.Shutdown;" \
  "API_DOCUMENTATION must use Shutdown instead of stale Disconnect"
require_fixed "$api_doc" "function Connect: Boolean;" \
  "API_DOCUMENTATION ISSLConnection section must publish the current Connect signature"
require_fixed "$api_doc" "下面列的是当前常用连接方法切片，不是 \`v1.5.0\` 当前 shipped source 的完整逐行镜像。" \
  "API_DOCUMENTATION ISSLConnection section must classify itself as a current slice instead of full shipped truth"
require_fixed "$api_doc" "完整 source-truth 请看 \`docs/reference/API_REFERENCE.md\`。" \
  "API_DOCUMENTATION ISSLConnection section must route full source truth to API_REFERENCE"
require_fixed "$api_doc" "function Write(const ABuffer; ACount: Integer): Integer;" \
  "API_DOCUMENTATION ISSLConnection section must publish the current raw Write signature"
require_fixed "$api_doc" "function WriteString(const AStr: string): Boolean;" \
  "API_DOCUMENTATION ISSLConnection section must publish the current WriteString helper"
require_fixed "$api_doc" "function Read(var ABuffer; ACount: Integer): Integer;" \
  "API_DOCUMENTATION ISSLConnection section must publish the current raw Read signature"
require_fixed "$api_doc" "function ReadString(out AStr: string): Boolean;" \
  "API_DOCUMENTATION ISSLConnection section must publish the current ReadString helper"
require_fixed "$api_doc" "下面这组 \`GetOCSP*\` 条目之所以仍保留在 \`ISSLConnection\` 小节，是因为当前 shipped source 仍向后兼容这些 compatibility-core mirrors。" \
  "API_DOCUMENTATION must classify ISSLConnection GetOCSP* entries as compatibility-core mirrors"
require_fixed "$api_doc" "新代码优先通过 \`ISSLOCSPStapling\` 读取 stapling 状态 / response / verify status / status string。" \
  "API_DOCUMENTATION must route new OCSP stapling guidance through ISSLOCSPStapling at section level"
require_fixed "$api_doc" "CertVerify: ISSLCertificateVerification;" \
  "API_DOCUMENTATION troubleshooting must declare the current certificate-verification owner interface"
require_fixed "$api_doc" "if Supports(Connection, ISSLCertificateVerification, CertVerify) and" \
  "API_DOCUMENTATION troubleshooting must query verify-result state through ISSLCertificateVerification"
require_fixed "$api_doc" "WriteLn('证书验证失败: ', CertVerify.GetVerifyResultString);" \
  "API_DOCUMENTATION troubleshooting must use current verify-result owner path"
require_absent "$api_doc" "**版本:** 2.0.0" \
  "API_DOCUMENTATION must stop advertising stale 2.0.0 version"
require_absent "$api_doc" "nextpas.core.tls.base," \
  "API_DOCUMENTATION must stop teaching split base-unit imports in active examples"
require_absent "$api_doc" "nextpas.core.tls.factory," \
  "API_DOCUMENTATION must stop teaching split factory-unit imports in active examples"
require_absent "$api_doc" "WithSystemRootCerts" \
  "API_DOCUMENTATION must stop using stale WithSystemRootCerts builder name"
require_absent "$api_doc" "CreateConnection(443)" \
  "API_DOCUMENTATION must stop teaching CreateConnection(port)"
require_absent "$api_doc" "Connect('example.com', 443)" \
  "API_DOCUMENTATION must stop teaching Connect(host, port)"
require_absent "$api_doc" "Connection.Disconnect;" \
  "API_DOCUMENTATION must stop using stale Disconnect"
require_absent "$api_doc" "function Connect(const AHost: string; APort: Word): Boolean;" \
  "API_DOCUMENTATION ISSLConnection section must stop publishing stale Connect(host, port)"
require_absent "$api_doc" "function Write(const AData: TBytes): Integer;" \
  "API_DOCUMENTATION ISSLConnection section must stop publishing stale Write(TBytes) overload"
require_absent "$api_doc" "function Write(const AData: string): Integer;" \
  "API_DOCUMENTATION ISSLConnection section must stop publishing stale string Write overload"
require_absent "$api_doc" "function Read(var ABuffer: TBytes; AMaxLen: Integer): Integer;" \
  "API_DOCUMENTATION ISSLConnection section must stop publishing stale Read(TBytes) signature"
require_absent "$api_doc" "Connection.GetLastError" \
  "API_DOCUMENTATION must stop using nonexistent connection-level GetLastError"
require_absent "$api_doc" "Connection.GetPeerCertificateVerified" \
  "API_DOCUMENTATION must stop using nonexistent GetPeerCertificateVerified"
require_absent "$api_doc" "Connection.GetVerifyResult" \
  "API_DOCUMENTATION must stop teaching direct core verify-result mirror usage in active docs"
require_absent "$api_doc" "Connection.GetVerifyResultString" \
  "API_DOCUMENTATION must stop teaching direct core verify-result string mirror usage in active docs"

require_fixed "$winssl_practices" "(LConn as ISSLClientConnection).SetServerName('example.com');" \
  "WINSSL_BEST_PRACTICES must set example.com through ISSLClientConnection"
require_fixed "$winssl_practices" "(LConn as ISSLClientConnection).SetServerName('localhost');" \
  "WINSSL_BEST_PRACTICES must set localhost through ISSLClientConnection in local-test guidance"
require_absent "$winssl_practices" "LConn.Connect('example.com', 443);" \
  "WINSSL_BEST_PRACTICES must stop teaching Connect(host, port) for external tests"
require_absent "$winssl_practices" "LConn.Connect('localhost', 8443);" \
  "WINSSL_BEST_PRACTICES must stop teaching Connect(host, port) for local tests"

require_fixed "$winssl_guide" 'WinSSL 与 OpenSSL/WolfSSL/MbedTLS 共享统一的核心 public interface，但具体 published capability 仍以后端的 `ISSLLibrary.GetCapabilities` 为准。' \
  "WINSSL_USER_GUIDE must explain core-interface parity without claiming full backend identity"
require_fixed "$winssl_guide" '像 password callback、DER/PKCS8 私钥导入、PKCS#12 helper 范围这类能力，仍然属于 backend-specific published truth。' \
  "WINSSL_USER_GUIDE must call out backend-specific capability boundaries"
require_absent "$winssl_guide" "完全相同的接口" \
  "WINSSL_USER_GUIDE must stop claiming identical interfaces"

echo "[PASS] active connection API docs truth contract passed"
