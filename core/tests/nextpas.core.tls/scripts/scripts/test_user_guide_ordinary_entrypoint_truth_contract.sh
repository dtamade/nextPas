#!/usr/bin/env bash
set -euo pipefail

DOC="docs/guides/USER_GUIDE.md"

python3 - "$DOC" <<'PY'
from pathlib import Path
import sys

doc = Path(sys.argv[1]).read_text(encoding="utf-8")

def require(cond: bool, msg: str) -> None:
    if not cond:
        print(f"[FAIL] {msg}")
        raise SystemExit(1)

require(
    "本节前两个主场景优先展示当前普通新代码入口：`uses fafafa.ssl, nextpas.core.tls.context.builder;` + `TSSLContextBuilder` / `TSSLConnector` / `TSSLAcceptor` / `TSSLStream`。" in doc,
    "USER_GUIDE must explicitly declare the ordinary-user main entrypoint for the first two scenarios",
)
require(
    "如果你要固定 backend、或直接读取挂在连接对象上的 low-level owner surface，再回到 `ISSLLibrary` / `ISSLContext` / `CreateConnection(...)`。" in doc,
    "USER_GUIDE must distinguish ordinary entrypoint from low-level fixed-backend/direct paths",
)

try:
    client = doc.split("### 场景 1: HTTPS 客户端", 1)[1].split("### 场景 2: HTTPS 服务器", 1)[0]
    server = doc.split("### 场景 2: HTTPS 服务器", 1)[1].split("### 场景 3: 证书验证与管理", 1)[0]
except IndexError:
    require(False, "USER_GUIDE scenario headings changed unexpectedly")

for needle in [
    "nextpas.core.tls.context.builder;",
    "LTLS: TSSLConnector;",
    "LStream: TSSLStream;",
    "LContext := TSSLContextBuilder.Create",
    ".WithSystemRoots",
    "LTLS := TSSLConnector.FromContext(LContext);",
    "LStream := LTLS.ConnectSocket(ConnectToServer('example.com', 443), 'example.com');",
    "LConn := LStream.Connection;",
]:
    require(needle in client, f"client scenario lost ordinary-user builder/connector truth: {needle}")

for stale in [
    "LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);",
    "LContext := LLib.CreateContext(sslCtxClient);",
    "LConn := LContext.CreateConnection(ConnectToServer('example.com', 443));",
    "LClientConn := LConn as ISSLClientConnection;",
    "LClientConn.SetServerName('example.com');",
]:
    require(stale not in client, f"client scenario still teaches stale low-level entrypoint: {stale}")

for needle in [
    "nextpas.core.tls.context.builder;",
    "LAcceptor: TSSLAcceptor;",
    "LStream: TSSLStream;",
    "LContext := TSSLContextBuilder.Create",
    ".WithCertificate('server.crt')",
    ".WithPrivateKey('server.key')",
    ".WithVerifyNone  // 普通单向 TLS server；如需 mTLS 改用 WithMutualTLS(...)",
    ".BuildServer;",
    "LAcceptor := TSSLAcceptor.FromContext(LContext);",
    "LStream := LAcceptor.AcceptSocket(AcceptClient);",
    "LConn := LStream.Connection;",
]:
    require(needle in server, f"server scenario lost ordinary-user builder/acceptor truth: {needle}")

for stale in [
    "LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);",
    "LContext := LLib.CreateContext(sslCtxServer);",
    "LConn := LContext.CreateConnection(AcceptClient);",
]:
    require(stale not in server, f"server scenario still teaches stale low-level entrypoint: {stale}")

print("[PASS] user guide ordinary entrypoint truth contract passed")
PY
