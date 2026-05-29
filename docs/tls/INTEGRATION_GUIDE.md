# 将 `fafafa.ssl` 集成到你的网络通讯框架

`fafafa.ssl` 是一个 TLS 库：负责握手、加密/解密、证书与验证。

它 **不是** 网络通讯框架：

- 不负责 TCP connect/listen/accept
- 不负责 DNS 解析
- 不负责 HTTP 协议
- 不提供 event loop

你的网络层拥有并管理传输层（socket/stream）。`fafafa.ssl` 的定位是：在一个**已建立的传输之上跑 TLS**。

如果你想看一个可复用的 TCP 示例实现，可以参考 `examples/fafafa.examples.tcp.pas`（仅用于 examples，不属于库本体）。

---

## HTTP 传输 hooks（可选）

有些功能需要 HTTP（例如 OCSP 在线检查、CT log list 下载）。`fafafa.ssl` 仍然**不实现网络通信**，而是通过 hooks 让上层注入 HTTP GET/POST。

两种注入方式：

1) **Builder 注入到 context（推荐）**

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.context.builder;

// 你的网络框架实现这两个回调（示例签名）
// function HTTPGet(const AURL: string; ATimeoutMs: Integer): TSSLDataResult;
// function HTTPPost(const AURL, AContentType: string; const ABody: TBytes; ATimeoutMs: Integer): TSSLDataResult;

Ctx := TSSLContextBuilder.Create
  .WithVerifyPeer
  .WithSystemRoots
  .WithHTTPHooks(@Transport.HTTPGet, @Transport.HTTPPost)
  .BuildClient;
```

2) **线程局部注入**

当你只想在某个调用范围内临时提供传输，可用 `fafafa.ssl.net.hooks` 的 `TSSLHTTPHooksScope.Push/Pop`。

---

## 先选一个接入面

### 选项 A：直接用 `ISSLConnection`（更适合 event loop）

当你需要：

- 手动驱动握手（尤其是非阻塞）
- 自己控制重试、超时、调度

建议直接用 `ISSLConnection`：

- 每条传输创建一个 `ISSLConnection`
- 多条连接复用同一个 `ISSLContext`
- SNI/hostname 一定要在**连接级**设置（不要写进共享 context）

### 选项 B：用 `TSSLConnector/TSSLAcceptor` + `TSSLStream`（更适合阻塞流程）

当你需要：

- “连接一次就开始读写”的顺滑入口，或
- 上层协议已经以 `TStream` 作为抽象

可以用 `TSSLConnector/TSSLAcceptor` 和 `TSSLStream`。

注意：`TSSLStream` 只是把 `ISSLConnection` 包成 `TStream`，它仍然**不拥有**你的 socket；传输层的关闭还是你上层来做。

---

## 一次构建 Context，多次创建 Connection

大多数场景建议用 `fafafa.ssl.context.builder` 构建 context（示例：client）：

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.context.builder;

var
  Ctx: ISSLContext;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;
end;
```

之后复用 `Ctx`，为每个 socket/stream 创建一个新的 `ISSLConnection`。

---

## Socket 传输接入

### Client（阻塞握手）

前置条件：`YourConnectedSocket` 由你自己的网络代码创建并已连接到 `host:port`。

```pascal
uses
  SysUtils,
  fafafa.ssl;

var
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  CertVerify: ISSLCertificateVerification;
begin
  Conn := Ctx.CreateConnection(YourConnectedSocket);

  // SNI + hostname verification 是连接级配置。
  // 不要把 hostname 放在共享 ISSLContext（该路径已 deprecated）。
  ClientConn := Conn as ISSLClientConnection;
  ClientConn.SetServerName('example.com');

  Conn.SetTimeout(15000);
  Conn.SetBlocking(True);

  if not Conn.Connect then
  begin
    if Supports(Conn, ISSLCertificateVerification, CertVerify) then
      raise Exception.Create('TLS handshake failed: ' + CertVerify.GetVerifyResultString)
    else
      raise Exception.Create('TLS handshake failed');
  end;
end;
```

如果你已经在 `TSSLConnectionBuilder` / `TSSLConnector` / `TSSLAcceptor` 上配置了 timeout/blocking，这里的 `Conn.SetTimeout` / `Conn.SetBlocking` 更适合作为 direct-connection 场景下的局部 override。

### Client（非阻塞握手驱动）

这段结构用于 event loop 集成。`WaitSocketReadable/WaitSocketWritable` 是伪代码，你需要用自己的 poll/epoll/kqueue/IOCP 去实现。

```pascal
uses
  SysUtils,
  fafafa.ssl;

var
  State: TSSLHandshakeState;
  CertVerify: ISSLCertificateVerification;
begin
  Conn.SetBlocking(False);

  while True do
  begin
    State := Conn.DoHandshake;
    case State of
      sslHsCompleted:
        Break;
      sslHsInProgress:
        begin
          if Conn.WantRead then
            WaitSocketReadable(YourConnectedSocket, Conn.GetTimeout);
          if Conn.WantWrite then
            WaitSocketWritable(YourConnectedSocket, Conn.GetTimeout);
        end;
    else
      begin
        if Supports(Conn, ISSLCertificateVerification, CertVerify) then
          raise Exception.Create('TLS handshake failed: ' + CertVerify.GetVerifyResultString)
        else
          raise Exception.Create('TLS handshake failed');
      end;
    end;
  end;
end;
```

要点：

- `WantRead/WantWrite` 描述 TLS 层“希望底层传输满足的就绪条件”。
- 超时与取消最好由你的框架统一管理。`Conn.SetTimeout` 是连接级配置，但上层仍然应该负责 timer/cancel；如果你走的是 connector / acceptor facade，新代码优先在构建阶段使用 `.WithTimeout(...)`。

### 非阻塞读写的常见处理方式

读写通常和握手一样处理：

```pascal
var
  R: Integer;
  Err: TSSLErrorCode;
begin
  R := Conn.Read(Buffer, BufferSize);
  if R < 0 then
  begin
    Err := Conn.GetError(R);
    if Err = sslErrWouldBlock then
    begin
      if Conn.WantRead then WaitSocketReadable(YourConnectedSocket, Conn.GetTimeout);
      if Conn.WantWrite then WaitSocketWritable(YourConnectedSocket, Conn.GetTimeout);
    end
    else
      raise Exception.Create('TLS read failed');
  end;
end;
```

如果你用的是 `TSSLStream`，读写失败会抛异常（而不是返回 `-1`）。

### Shutdown 与“谁关闭 socket”

`fafafa.ssl` 不会帮你关闭 socket。

- `Conn.Shutdown`：尝试做 TLS 的优雅关闭（close_notify）
- socket 的真正关闭：由你的网络层完成

---

## `TStream` 传输接入

当你的网络层已经抽象出了一个“可读写的 duplex stream”，可以直接用 `ConnectStream`：

```pascal
uses
  SysUtils,
  fafafa.ssl;

var
  TLS: TSSLConnector;
  Stream: TSSLStream;
begin
  TLS := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));
  Stream := TLS.ConnectStream(YourDuplexStream, 'example.com');
  try
    // Stream.Read / Stream.Write
  finally
    Stream.Free;
  end;
end;
```

如果你要把 resumed session + TLS 1.3 early data 一起收口到 connector facade，可以这样写：

```pascal
uses
  SysUtils, Classes,
  fafafa.ssl,
  fafafa.ssl.context.builder;

var
  Ctx: ISSLContext;
  Session: ISSLSession;
  Resumption: ISSLSessionResumption;
  TLS: TSSLConnector;
  InitialStream: TSSLStream;
  Stream: TSSLStream;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithClientEarlyData(True)
    .BuildClient;

  InitialStream := TSSLConnector.FromContext(Ctx)
    .ConnectStream(InitialTransport, 'example.com');
  try
    if Supports(InitialStream.Connection, ISSLSessionResumption, Resumption) then
      Session := Resumption.GetSession;
  finally
    InitialStream.Free;
  end;

  TLS := TSSLConnector.FromContext(Ctx)
    .WithSession(Session)
    .WithEarlyData(BytesOf('PING'));

  Stream := TLS.ConnectStream(ResumedTransport, 'example.com');
  try
    // handshake 成功后再继续应用层读写
  finally
    Stream.Free;
  end;
end;
```

这里有两个边界要记住：

- context 仍然需要先通过 `WithClientEarlyData(True)`（或 `ISSLEarlyDataContext`）启用 client early-data
- `TSSLConnector.WithEarlyData(...)` 只负责在 `Connect` 前 queue payload，不会偷偷修改 context 或绕过 session/resumption 前提

你的 `TStream` 仍然负责底层连接的生命周期（打开/关闭/超时/取消）。

如果你在 FreePascal server 侧想把 resumed early-data 的 anti-replay truth 从默认内存 ledger 接到一个 file-backed replay store，推荐走 `TSSLContextConfig` / `TSSLFactory` context-safe 路径：

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.context.builder;

var
  LConfig: TSSLContextConfig;
  ServerCtx: ISSLContext;
begin
  LConfig := CreateDefaultContextConfig(sslCtxServer);
  LConfig.LibraryType := sslFreePascal;
  LConfig.CertificateFile := 'server.crt';
  LConfig.PrivateKeyFile := 'server.key';
  LConfig.ServerEarlyDataPolicy := sslEarlyDataServerAccept;
  LConfig.ServerMaxEarlyDataSize := 16384;
  LConfig.ServerEarlyDataReplayStoreFile := '/var/lib/myapp/early-data.replay';

  ServerCtx := TSSLFactory.CreateContext(LConfig);
end;
```

> v1.x 兼容：旧代码仍可使用 `TSSLConfig` + `CreateDefaultConfig(...)` 走同样的 factory 路径，行为不变。

这条路径当前有四个边界：

- `ServerEarlyDataReplayStoreFile` 只对 FreePascal server path 生效；未配置或空串时，默认 shipped path 仍会落到本地持久化 replay-store 目录，默认路径不可用或不可写时 fail-closed reject resumed early data
- 这只是 caller-controlled path placement 的 opt-in seam；默认 shipped path 已经提供本地持久化 replay truth，但这不表示 distributed readiness 已完成
- callback / file-backed 路径上的本地 `enabled` / `capacity` toggle 用来控制当前 ledger gate，不应理解成会隐式 wipe 已共享或已持久化的 replay truth
- 这条 opt-in 也不会把 `experimental` capability wording 自动升级成更强承诺；当前 shipped path 已经是 local persistent anti-replay replay-store，但如果你需要更重的 provider/distributed durability 语义，应单独评估

---

## 用 ALPN 做 TLS 级协议协商

ALPN 由 TLS 协商，但“协商后要做什么”（例如 HTTP/2 vs HTTP/1.1）属于你上层协议栈的范畴。

运行：

```pascal
Ctx.SetALPNProtocols('h2,http/1.1');
```

握手成功后：

```pascal
var ConnInfo: ISSLConnectionInfo;
if Supports(Conn, ISSLConnectionInfo, ConnInfo) then
  WriteLn('Selected ALPN: ', ConnInfo.GetSelectedALPNProtocol);
```

---

## 排错与诊断

握手失败时，优先看这些：

- `CertVerify.GetVerifyResult` / `CertVerify.GetVerifyResultString`（证书验证结果；通过 `ISSLCertificateVerification` 获取）
- `Conn.GetProtocolVersion` / `Conn.GetCipherName`
- `ConnInfo.GetStateString`（后端相关的状态描述；通过 `ISSLConnectionInfo` 获取）

---

## 值得直接抄的示例

- `examples/01_tls_client.pas`
- `examples/https_simple_get.pas`
- `examples/https_client/README.md`
- `examples/fafafa.examples.tcp.pas`（TCP helper，仅用于示例）
