# nextpas.core.http 模块架构设计

## 概述

HTTP 模块是 L3 框架层的核心模块，提供 HTTP 服务器和客户端能力。
采用统一门面 + 协议实现隔离的架构。当前内建 transport 实现为 HTTP/1.1；
H2 已开始落内部 codec foundation（frame、HPACK Huffman、HPACK request sequence header block），
但还没有内建 H2 transport/session。H3 仍只保留版本枚举、registry / transport seam 与规划。
这些内部基础不声明内建 H2/H3 protocol implementation。

消费方只需 `uses nextpas.core.http` 即可获得当前 H1 能力；默认版本解析对应用层透明。
H2/H3 对消费方仍处于未开放阶段。

## 当前落地状态（2026-06-12）

- `nextpas.core.http.impl.h1.pas` 已落地，作为默认 H1 transport owner。
- `nextpas.core.http.impl.registry.pas` 已落地，统一负责默认版本到 transport factory 的解析。
- `http.base` 现在拥有 `THttpClientOptions` / `THttpServerOptions` 这两个公共 options carrier。
- `nextpas.core.http.client.pas` / `nextpas.core.http.server.pas` 现在主要承担编排骨架职责：client 负责重定向/便捷请求构造，server 是建立在 `nextpas.core.net.server` 之上的 HTTP facade。
- 当前扩展 seam 已经是显式 transport 注入：`NewHttpClient([Transport][, Options])`、`NewHttpServer(Handler[, Transport][, Options])`。
- `THttpServerOptions.Backend` 现在是公开 runtime seam：HTTP facade 会把它原样下沉到 `nextpas.core.net.server` foundation。
- 当前内建注册是 `hvHttp10` / `hvHttp11` -> H1，默认 client/server 版本都为 `hvHttp11`。
- 当前真实源码库存为 29 个 HTTP 单元，测试工程为 26 个；其中 H2 只有
  frame codec、HPACK Huffman 和 HPACK request-sequence header-block 内部基础单元及
  focused 测试，H2 transport/session 与 H3 仍未进入可用实现。

HTTP server runtime 的权威方向已经固定在
[docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md:1)：
HTTP 保持同步 public surface，listener/runtime/backend ownership 由
`nextpas.core.net.server` 统一负责。

## 当前 runtime 真相

HTTP server 现在要分三层理解，不能再笼统地说成“线程驱动 HTTP server”：

- public layer：
  `IHttpServer` / `IHttpHandler` 继续保持同步、直线型 contract。
- foundation runtime layer：
  backend 选择、listen / accept / shutdown、worker handoff 已经下沉到
  `nextpas.core.net.server`。
- protocol layer：
  `TH1ServerConnectionState` 已经是独立的 per-connection H1 state object，
  并且现在也能接住 foundation 传下来的 `ITcpServerSessionContext` /
  `WorkerHandoff`。

当前 backend 状态也要说清楚：

- 默认 backend 仍是 `threaded`，它是 correctness baseline。
- backend 解析现在经由 `nextpas.core.net.server` 的 factory registry seam 完成，
  不再写死在 HTTP facade。
- Linux `epoll` 已经落到 phase 1：evented accept + worker-driven connection execution。
- `nextpas.core.net.server` 现在也已具备 poll-driven session seam，
  而且 H1 session 现在已经开始消费这条 seam；
  但当前还不是完整 reactor-owned H1 state machine。
- H1 现在已经能看到 foundation session context；并且 foundation `epoll` runtime
  也已经具备 worker-completion -> reactor wakeup 与 deadline wake 的基础能力。
- `TH1ServerConnectionState` 现在已经实现 `ITcpServerPollDrivenSession`，
  reactor 现在已经直接负责 request-side read/parse，
  并且会把每个已完成 request 单独通过 `WorkerHandoff` 提交，
  同连接里已经缓冲好的 follow-up request 不必再等待新的 readability 才能继续。
- H1 poll path 现在又向前推进了一格：
  successful response 现在统一走 reactor-owned drain：
  worker 只负责 response production，
  completion wake 回到 reactor 后会立即尝试一次 nonblocking drain，
  若 socket `would-block` 则转成 `peWritable` 继续 drain；
  当 `WriteTimeout > 0` 时，这条 drain 还会暴露有限 `WakeDeadline`，
  deadline 到期则安全关闭 stalled session。
- poll-owned request worker 现在也不再直接回写 reactor 共享 response state：
  worker 只生成本次 request 的 outbound/result，
  completion 回到 reactor 后再把结果应用到 poll state machine，
  避免把 queue / keep-alive / close 语义直接散落在 worker 线程里。
- H1 poll path 现在已经固定了一条有界 response queue 语义：
  active drain + 1 queued response。
  这允许 untimed path 在首个响应尚未开始 socket drain 时，
  先把一个 buffered follow-up request 完成为第二个有序 response；
  follow-up parse 产生的 `400` / `413` / `431` 也会排在前一个响应之后，
  不会打乱 wire 顺序。
- 同时 timed / backpressure safety boundary 仍保持收紧：
  `WriteTimeout > 0` 时，completion wake 仍先尝试第一次 nonblocking drain，
  一旦进入 stalled timed drain，就不会再继续消费后续 pipelined request。
- H1 server response path 现在已经完成一层关键拆分：
  handler 先把响应写入 internal outbound buffer，
  `TH1ServerConnectionState` 再在 handler 返回后统一 drain 到 socket。
- H1 server ingress 现在也有一条保守 fast path：
  对完整 HTTP/1.1、恰好一个非空 `Host`、无 `Connection` / `Expect` /
  `Transfer-Encoding`、且无 request body 的普通请求，先用
  `nextpas.core.http.impl.h1.fast.FastParseRequest` 构造请求 snapshot；
  其他请求一律回退 llhttp adapter，继续沿用既有 malformed framing、
  chunked、body、Expect 与 connection-policy 安全契约。
- 因此 H1 剩余的真实阻塞点已经进一步收窄为：
  timed write/drain state machine / `WakeDeadline` /
  write-timeout close 语义，
  不再是 request-side read/parse，也不再是 context bridge / reactor wakeup 基础设施本身，
  也不应该再把“handler 必须同步阻塞在 socket write 上”当成固定方向。
- 当前 phase 2 的真实状态应精确表述为：
  - read/parse 已 reactor-owned
  - per-request handoff 已 reactor-owned
  - successful response drain 已 reactor-owned
  - timed drain / `WakeDeadline` 也已进入同一条 response state machine
  - active + 1 queued response 已落地，并已锁定有序 follow-up error response
  - 当前剩余缺口已收窄为 stalled-peer timing characterization、close-observation 与性能优化，而不是 H1 poll foundation 本身
- 但这里还有一条必须写死的边界：
  当前 `TH1ServerConnectionState + ITcpServerPollDrivenSession` 是 readiness-family
  driver seam，适配 Linux `epoll` 与 future `kqueue` 没问题；
  future Windows `IOCP` 要共享的是同一个 H1 state object ownership，
  不是让 HTTP 自己长出一套 Windows-specific readable / writable 分支。

因此 HTTP 这层的固定方向不是“自己长出一个更复杂的 `TBaseServer`”，而是：

- 保持 HTTP facade 简单
- 把 runtime 演进集中在 `nextpas.core.net.server`
- 让 H1/H2/H3 都接到同一种 session-driven foundation 上
- 允许 foundation 为 `IOCP` 补 completion-aware driver，而不是要求 HTTP 协议层伪装它
  和 `epoll` 完全同形

---

## 架构分层

```
┌─────────────────────────────────────────────────────────┐
│  门面层 (nextpas.core.http)                              │
│  统一 re-export，消费方唯一入口                          │
├─────────────────────────────────────────────────────────┤
│  应用层（跨版本共享）                                    │
│  Request / Response / Headers / Router / Middleware      │
│  Server facade / Client facade                           │
├─────────────────────────────────────────────────────────┤
│  内部 registry 层                                        │
│  默认版本解析 + transport factory 注册                   │
├─────────────────────────────────────────────────────────┤
│  协议实现层（版本隔离）                                  │
│  impl.h1: 文本协议、chunked、keep-alive、upgrade       │
│  impl.h2 (planned): 二进制帧、多路复用、HPACK、ALPN   │
│  impl.h3 (planned): QUIC 帧、QPACK、0-RTT、Alt-Svc   │
├─────────────────────────────────────────────────────────┤
│  依赖层                                                  │
│  H1: net (TCP)                                           │
│  H2 future: net (TCP) + tls (ALPN)                       │
│  H3 future: quic (独立 L2 sibling 模块)                  │
└─────────────────────────────────────────────────────────┘
```

---

## 文件结构（当前已落地）

```
src/
  { 门面 + 公共层 }
  nextpas.core.http.pas                  ← 统一门面（re-export）
  nextpas.core.http.base.pas             ← 公共类型 + public options carrier
  nextpas.core.http.intf.pas             ← 统一接口
  nextpas.core.http.message.pas          ← Request/Response 实现
  nextpas.core.http.headers.pas          ← Header 集合（解析/序列化/查找）
  nextpas.core.http.url.pas              ← URL 解析（scheme/host/path/query/fragment）
  nextpas.core.http.router.pas           ← Radix tree 路由 + 路径参数
  nextpas.core.http.middleware.pas       ← 中间件链
  nextpas.core.http.middleware.cors.pas
  nextpas.core.http.middleware.logger.pas
  nextpas.core.http.middleware.recovery.pas
  nextpas.core.http.middleware.timeout.pas
  nextpas.core.http.server.pas           ← Server facade（委托 nextpas.core.net.server）
  nextpas.core.http.client.pas           ← Client 骨架（redirect + helper request build）
  nextpas.core.http.static.pas           ← 静态文件/目录服务
  nextpas.core.http.websocket.pas        ← WebSocket upgrade 与 frame IO

  { 内部默认协议解析 }
  nextpas.core.http.impl.registry.pas    ← 默认版本注册表 + transport factory 解析

  { HTTP/1.1 实现 }
  nextpas.core.http.impl.h1.pas          ← H1 transport owner（client round-trip + server per-conn serve）
  nextpas.core.http.impl.h1.llhttp.pas   ← llhttp 翻译产物
  nextpas.core.http.impl.h1.parser.pas   ← H1 协议解析（基于 llhttp 翻译）
  nextpas.core.http.impl.h1.scan.pas     ← H1 扫描辅助
  nextpas.core.http.impl.h1.fast.pas     ← H1 快速解析路径
  nextpas.core.http.impl.h1.outbound.pas ← H1 internal outbound queue/drain helper
  nextpas.core.http.impl.h1.writer.pas   ← H1 响应序列化
  nextpas.core.http.impl.h1.chunked.pas  ← chunked writer/helper

  { HTTP/2 内部 codec foundation（不等于 H2 transport/session 已可用） }
  nextpas.core.http.impl.h2.frame.pas         ← H2 9-byte frame header 与基础 payload codec
  nextpas.core.http.impl.h2.hpack.table.pas   ← HPACK static/Huffman 表
  nextpas.core.http.impl.h2.hpack.huffman.pas ← HPACK Huffman encode/decode
  nextpas.core.http.impl.h2.hpack.pas         ← HPACK request-sequence header-block encode/decode
```

H2/H3 public transport 仍是架构规划；当前 H2 源码只覆盖 HPACK Huffman、
HPACK request-sequence header-block 和 frame codec 内部基础，不对外声明 H2 可用。

---

## 接口设计

### 公共类型 (http.base)

```pascal
type
  THttpVersion = (hvHttp10, hvHttp11, hvHttp2, hvHttp3);
  THttpMethod = (hmGet, hmHead, hmPost, hmPut, hmDelete, hmPatch, hmOptions, hmConnect, hmTrace);
  THttpStatus = UInt16;

  TUrl = record
    Scheme: string;
    UserInfo: string;
    Host: string;
    Port: UInt16;
    Path: string;
    RawQuery: string;
    Fragment: string;
    class function Parse(const ARaw: string): TUrl; static;
    class function ParseRequestTarget(const ARaw: string): TUrl; static;
    function ToString: string;
    function HostPort: string;
  end;
```

### 统一接口 (http.intf)

这是 current API snapshot，不是完整 reference；完整签名以 `src/nextpas.core.http.intf.pas` 为准。

```pascal
type
  IHttpHeaders = interface
    procedure SetHeader(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Remove(const AName: string);
    procedure Clear;
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
  end;

  IHttpRequest = interface
    { handler/router hot path should prefer Path / RawQuery over full Url materialization. }
    property Method: THttpMethod read GetMethod;
    property Url: TUrl read GetUrl;
    property Version: THttpVersion read GetVersion;
    property Path: string read GetPath;
    property RawQuery: string read GetRawQuery;
    property Headers: IHttpHeaders read GetHeaders;
    property Body: IReader read GetBody;
    property ContentLength: Int64 read GetContentLength;
    property RemoteAddr: string read GetRemoteAddr;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
  end;

  IHttpResponseWriter = interface
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Headers: IHttpHeaders read GetHeaders;
  end;

  THttpHandlerFunc = reference to procedure(const AReq: IHttpRequest; const AResp: IHttpResponseWriter);
  THttpHandlerMethod = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) of object;
  THttpHandlerProc = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter);

  { Router }
  IHttpRouter = interface(IHttpHandler)
    procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Get(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Head(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Post(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Put(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Delete(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Patch(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Options(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Connect(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Trace(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Use(const AMiddleware: IHttpMiddleware);
  end;

  IHttpServer = interface
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

  IHttpClient = interface
    function Send(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
    function Get(const AUrl: string): IHttpResponse;
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    { Put/Delete/Patch/Head and string/TBytes body overloads are also available. }
  end;

  IHttpTransport = interface
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  IHttpServerTransport = interface
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
  end;

  IHttpServerSessionFactory = interface
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
  end;

  IHttpServerSessionFactoryWithContext = interface
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  end;
```

### Server runtime ownership

- `nextpas.core.http.server` 不再拥有自己的通用 accept/thread runtime。
- 真实 listener / accept / shutdown / backend 选择由 `nextpas.core.net.server` 提供。
- `IHttpServerTransport` 是 per-connection protocol seam，不是整机 runtime seam。
- hijack / detach 这类 ownership 语义通过 `TTcpServerConnOwnership` 与 TCP foundation 对齐。
- `IHttpServerTransport.ServeConn` 为兼容仍保留，但 future backend 不应再只依赖这个整连接阻塞入口。
- `IHttpServerSessionFactory` / `ITcpServerSession` 才是 HTTP 接入 future evented runtime 的主 seam。
- `TH1ServerConnectionState` 必须继续保持“协议状态对象”身份；
  `epoll` / `kqueue` / `IOCP` 差异只能落在 foundation runtime driver，不应把 socket
  调度策略重新拉回 HTTP 层。
- `IOCP` 若最终需要 completion-aware foundation driver，也应该通过 `net.server`
  seam 接入；HTTP 不应为此暴露新的 public callback-first API，也不应引入
  Windows-only handler contract。

### 版本特有接口（不进 http.intf，留在各自 impl 内部）

- `IHttp1Upgrader` — WebSocket 升级
- `IHttp2Session` / `IHttp2Stream` — H2 流管理
- `IHttp3Session` — H3 会话

---

## 依赖关系

```
http.base       ← errors, net.server.base
http.intf       ← base, http.base, io.intf, net.base, net.intf, net.server.base/intf
http.headers    ← http.base, text, collections
http.url        ← http.base, text
http.message    ← http.intf, http.headers, io
http.router     ← http.intf, collections
http.middleware ← http.intf
http.server     ← http.base, http.intf, net.base, net.intf, net.server, impl.registry
http.client     ← http.base, http.intf, io, text, impl.registry

impl.registry   ← http.base, http.intf, impl.h1
impl.h1.*       ← http.base, http.intf, net, io, text
impl.h2.*       ← planned: http.intf, net, tls, io, collections
impl.h3.*       ← planned: http.intf, quic, io, collections
```

---

## H1 Parser 策略

基于 llhttp（Node.js 官方 HTTP parser）：

- 用 c2pas888 项目翻译 llhttp C 源码为 Pascal
- 修正为 nextpas 框架风格（命名规范、异常处理）
- 放入 `nextpas.core.http.impl.h1.parser.pas`
- 通过 H1 transport、`IHttpServerTransport` 兼容入口，以及
  `IHttpServerSessionFactory*` evented runtime seam 被 server/client 消费

llhttp 优势：

- 生产级验证（Node.js 全球流量）
- 完整 HTTP/1.1 语义（chunked、keep-alive、upgrade、trailers）
- 回调式 API 天然适合流式解析
- RFC 合规性极高

---

## 演进路线

### Phase 1: HTTP/1.1（当前目标）

```
http.base + http.intf + http.headers + http.url
+ http.message + http.router + http.middleware
+ http.server + http.client
+ impl.h1 + impl.h1.parser/scan/fast/writer/chunked
+ impl.registry
```

依赖：net, net.server, io, text, time
测试：完整接口覆盖 + echo server + client round-trip + router dispatch + registry default resolution
Benchmark：对照 Go `net/http`、Rust std-only comparator，并在需要更真实 Rust
生态对照时追加可选 Hyper/Tokio comparator；当前不把任何单一 comparator row
表述成完整 Rust 生态结论

### Phase 2: HTTP/2

```
+ impl.h2.* transport 家族
+ registry 扩展到 H2 默认解析 / ALPN 接线
```

依赖：新增 tls
触发条件：TLS 模块就绪后

### Phase 3: HTTP/3

```
+ nextpas.core.quic (独立 L2 模块)
+ impl.h3.frame + impl.h3.qpack + impl.h3.stream + impl.h3.conn
```

依赖：新增 quic
触发条件：QUIC 模块就绪后

---

## 设计原则

1. **消费方只 `uses nextpas.core.http`** — 版本协商完全透明
2. **Handler 是核心抽象** — 所有版本共享同一个 handler 签名
3. **Body 是 IReader** — 流式读取，不缓冲整个 body
4. **异常传播** — handler 内部异常在 server 边界捕获，返回 500
5. **接口驱动** — Server/Client/Transport 全部通过 interface 暴露
6. **runtime ownership 下沉** — HTTP 不拥有线程模型、event loop 或 IOCP 策略
7. **H2/H3 不污染 H1** — 条件编译或独立链接单元
8. **Router 内建** — 不需要第三方路由库（Radix tree，O(path_length)）
