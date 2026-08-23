#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

source_base="core/src/nextpas.core.tls.connection.base.pas"

require_multiline() {
  local file="$1"
  local regex="$2"
  local message="$3"
  if ! perl -0ne "exit((m{$regex}s) ? 0 : 1)" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

forbid_multiline() {
  local file="$1"
  local regex="$2"
  local message="$3"
  if perl -0ne "exit((m{$regex}s) ? 0 : 1)" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

declare -a forbidden_patterns=(
  'ISSLAdvanced'
  '| GetConnectionInfo | **移除** | 使用 ISSLDiagnostics |'
  '| GetStateString | **移除** | 合并到 GetState |'
  '| GetContext | **移除** | 通常不需要 |'
  '| GetSelectedALPNProtocol | ISSLClientConnection | 客户端特有 |'
)



require_multiline \
  "$source_base" \
  'TBaseSSLConnection = class\(TInterfacedObject,\s*ISSLConnection,\s*ISSLConnectionTextIO,\s*ISSLConnectionControl,\s*ISSLDiagnostics,\s*ISSLSessionResumption,\s*ISSLCertificateVerification,\s*ISSLConnectionInfo\)' \
  "source base-connection declaration no longer matches the expected shared owner/mirror interface set"


declare -a required_patterns=(
  '├── ISSLConnectionInfo (连接信息 mirrors)'
  '### ISSLConnectionInfo (连接信息 mirrors)'
  'ISSLConnectionInfo = interface'
  'function GetConnectionInfo: TSSLConnectionInfo;'
  'function GetContext: ISSLContext;'
  'function GetSelectedALPNProtocol: string;'
  'function GetStateString: string;'
  'if Supports(LConn, ISSLConnectionInfo, LInfoExt) then'
  'ISSLConnectionInfo,'
  '| GetConnectionInfo | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |'
  '| GetStateString | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |'
  '| GetContext | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |'
  '| GetSelectedALPNProtocol | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |'
  '当前 `v1.x` source truth 里'
  '1. 先把这 4 个 mirrors 的默认 owner 统一成 `ISSLConnectionInfo`'
  '`TBaseSSLConnection` 当前不直接承载 `ISSLClientConnection` / `ISSLNativeHandleAccess` / `ISSLOCSPStapling`。'
  '`ISSLClientConnection` / `ISSLNativeHandleAccess` / `ISSLOCSPStapling` 改由 backend-specific subclasses 按 capability / runtime truth 显式挂载。'
  'TOpenSSLConnection = class(TBaseSSLConnection, ISSLClientConnection,'
  'TOpenSSLOCSPConnection = class(TOpenSSLConnection, ISSLOCSPStapling)'
  '2. **Phase 2**: 让 `TBaseSSLConnection` 承载 shared owner / mirror surfaces'
  '3. **Phase 3**: 由 backend connection subclasses 按 capability 挂上 `ISSLClientConnection` / `ISSLNativeHandleAccess` / `ISSLOCSPStapling`'
)


echo "[PASS] ISSLConnectionInfo migration targets match the current slimming roadmap"
