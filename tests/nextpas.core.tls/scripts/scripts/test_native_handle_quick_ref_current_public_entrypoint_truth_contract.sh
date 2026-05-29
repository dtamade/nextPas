#!/usr/bin/env bash
set -euo pipefail

DOC="docs/NATIVE_HANDLE_QUICK_REF.md"

require_contains() {
  local pattern="$1"
  if ! rg -F -q "$pattern" "$DOC"; then
    echo "[FAIL] missing pattern: $pattern" >&2
    exit 1
  fi
}

require_absent() {
  local pattern="$1"
  if rg -F -q "$pattern" "$DOC"; then
    echo "[FAIL] unexpected pattern present: $pattern" >&2
    exit 1
  fi
}

require_contains '当前 public 入口说明：'
require_contains '普通 capability / native-handle 查询不必再拆分回 `uses nextpas.core.tls.base` / `nextpas.core.tls.factory`；`fafafa.ssl` 已 re-export `ISSLContext` / `ISSLNativeHandleAccess` / `TSSLFactory`。'
require_contains '需要固定 backend 并访问原生句柄时，当前 library-entrypoint 优先使用 `TSSLFactory.GetLibraryInstance(...)` + `Lib.CreateContext(...)`。'
require_contains '如果你只是普通客户端/服务端 TLS 建立，请优先回到 `docs/guides/GETTING_STARTED.md` 里的 `TSSLContextBuilder` / `TSSLConnector` / `TSSLStream` 主路径。'
require_contains '  fafafa.ssl,'
require_contains 'Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);'
require_contains 'Ctx := Lib.CreateContext(sslCtxClient);'

require_absent 'nextpas.core.tls.base,'
require_absent 'TSSLFactory.CreateContext(sslCtxClient, sslOpenSSL);'
require_absent 'CreateLibrary'

echo "[PASS] native-handle quick ref current public entrypoint truth contract passed"
