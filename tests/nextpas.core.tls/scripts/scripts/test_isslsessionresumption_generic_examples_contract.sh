#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

session_reuse_example="examples/session_reuse_example.pas"
session_resumption_example="examples/session_resumption_example.pas"
https_client_example="examples/https_client/https_client_session.pas"
production_example="examples/production/https_client_session.pas"
user_guide="docs/guides/USER_GUIDE.md"

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

require_absent_regex() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent_regex "$session_reuse_example" '\bConn\.(GetSession|SetSession|IsSessionReused)\b' \
  "session_reuse_example still uses direct core session-resumption mirror on Conn"
require_fixed "$session_reuse_example" "Resumption: ISSLSessionResumption;" \
  "session_reuse_example must declare the session-resumption owner interface"
require_fixed "$session_reuse_example" "Supports(Conn, ISSLSessionResumption, Resumption)" \
  "session_reuse_example must resolve the session-resumption owner path"
require_fixed "$session_reuse_example" "Resumption.SetSession(ACachedSession);" \
  "session_reuse_example must inject cached sessions through the owner path"
require_fixed "$session_reuse_example" "Resumption.IsSessionReused;" \
  "session_reuse_example must read reuse truth through the owner path"
require_fixed "$session_reuse_example" "Session := Resumption.GetSession;" \
  "session_reuse_example must capture sessions through the owner path"
require_fixed "$session_reuse_example" "ISSLSessionResumption.SetSession(...)." \
  "session_reuse_example note must point readers to the owner path"

require_absent_regex "$session_resumption_example" '\b(?:Conn|TLS\.Connection)\.(GetSession|SetSession|IsSessionReused)\b' \
  "session_resumption_example still uses direct core session-resumption mirrors"
require_fixed "$session_resumption_example" "Resumption: ISSLSessionResumption;" \
  "session_resumption_example must declare the session-resumption owner interface"
require_fixed "$session_resumption_example" "Resumption.SetSession(GSavedSession);" \
  "session_resumption_example must inject saved sessions through the owner path"
require_fixed "$session_resumption_example" "Supports(TLS.Connection, ISSLSessionResumption," \
  "session_resumption_example must read observed reuse through the owner path"
require_fixed "$session_resumption_example" "GSavedSession := Resumption.GetSession;" \
  "session_resumption_example must capture the saved session through the owner path"
require_fixed "$session_resumption_example" "未观测到恢复路径命中" \
  "session_resumption_example must distinguish warm misses from the first handshake"
require_fixed "$session_resumption_example" "是否真的命中恢复路径，请以 IsSessionReused 的运行输出为准。" \
  "session_resumption_example must keep the candidate-vs-observed truth note"
require_absent_fixed "$session_resumption_example" "会话复用已完美支持" \
  "session_resumption_example must stop claiming unconditional session-resumption support"
require_absent_fixed "$session_resumption_example" "显著提升性能" \
  "session_resumption_example must stop promising fixed performance gains"
require_absent_fixed "$session_resumption_example" "通过 OpenSSL API 检查是否真正复用了会话" \
  "session_resumption_example must stop describing reuse truth as an OpenSSL-only API path"

require_absent_regex "$https_client_example" '\bLConnection\.(GetSession|SetSession|IsSessionReused)\b' \
  "https_client_session example still uses direct core session-resumption mirrors"
require_fixed "$https_client_example" "LResumption: ISSLSessionResumption;" \
  "https_client_session example must declare the session-resumption owner interface"
require_fixed "$https_client_example" "Supports(LConnection, ISSLSessionResumption, LResumption)" \
  "https_client_session example must resolve the session-resumption owner path"
require_fixed "$https_client_example" "LResumption.SetSession(ACachedSession);" \
  "https_client_session example must inject cached sessions through the owner path"
require_fixed "$https_client_example" "LResumption.IsSessionReused;" \
  "https_client_session example must read reuse truth through the owner path"
require_fixed "$https_client_example" "LSession := LResumption.GetSession;" \
  "https_client_session example must capture sessions through the owner path"

require_absent_regex "$production_example" '\bLConnection\.(GetSession|SetSession|IsSessionReused)\b' \
  "production https_client_session example still uses direct core session-resumption mirrors"
require_fixed "$production_example" "LResumption: ISSLSessionResumption;" \
  "production https_client_session example must declare the session-resumption owner interface"
require_fixed "$production_example" "Supports(LConnection, ISSLSessionResumption, LResumption)" \
  "production https_client_session example must resolve the session-resumption owner path"
require_fixed "$production_example" "LResumption.IsSessionReused;" \
  "production https_client_session example must read reuse truth through the owner path"
require_fixed "$production_example" "共享上下文与 session candidate 可能减少握手成本" \
  "production https_client_session example must keep the session candidate caveat"
require_absent_fixed "$production_example" "会话复用可以显著减少TLS握手时间。" \
  "production https_client_session example must stop promising fixed handshake reductions"

require_fixed "$user_guide" "当前握手命中了恢复路径。" \
  "USER_GUIDE must use precise reuse wording"
require_absent_fixed "$user_guide" "握手更快！" \
  "USER_GUIDE must stop turning IsSessionReused into a guaranteed speed claim"

echo "[PASS] generic examples and high-entry guide prefer ISSLSessionResumption owner truth"

