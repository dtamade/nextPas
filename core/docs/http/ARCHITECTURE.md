# nextpas.core.http 模块架构设计

## 概述

HTTP 模块是 L3 框架层的核心模块，提供 HTTP 服务器和客户端能力。
采用统一门面 + 协议实现隔离的架构，支持 HTTP/1.1、HTTP/2、HTTP/3 三个版本。

消费方只需 `uses nextpas.core.http` 即可获得完整能力；当前默认版本解析对应用层透明，但 H2/H3 仍处于规划阶段。

## 当前落地状态（2026-06-03）

- `nextpas.core.http.impl.h1.pas` 已落地，作为默认 H1 transport owner。
- `nextpas.core.http.impl.registry.pas` 已落地，统一负责默认版本到 transport factory 的解析。
- `http.base` 现在拥有 `THttpClientOptions` / `THttpServerOptions` 这两个公共 options carrier。
- `nextpas.core.http.client.pas` / `nextpas.core.http.server.pas` 现在主要承担编排骨架职责：client 负责重定向/便捷请求构造，server 是建立在 `nextpas.core.net.server` 之上的 HTTP facade。
- 当前扩展 seam 已经是显式 transport 注入：`NewHttpClient([Transport][, Options])`、`NewHttpServer(Handler[, Transport][, Options])`。
- `THttpServerOptions.Backend` 现在是公开 runtime seam：HTTP facade 会把它原样下沉到 `nextpas.core.net.server` foundation。
- 当前内建注册是 `hvHttp10` / `hvHttp11` -> H1，默认 client/server 版本都为 `hvHttp11`。
- 当前真实源码库存为 24 个 HTTP 单元，测试工程为 21 个；H2/H3 仍未进入实现。

HTTP server runtime 的权威方向已经固定在
[docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md:1)：
HTTP 保持同步 public surface，listener/runtime/backend ownership 由
`nextpas.core.net.server` 统一负责。

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
│  impl.h2: 二进制帧、多路复用、HPACK、流控、ALPN        │
│  impl.h3: QUIC 帧、QPACK、0-RTT、Alt-Svc             │
├─────────────────────────────────────────────────────────┤
│  依赖层                                                  │
│  H1/H2: net (TCP) + tls (ALPN)                          │
│  H3: quic (独立 L2 sibling 模块)                        │
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
  nextpas.core.http.impl.h1.writer.pas   ← H1 响应序列化
  nextpas.core.http.impl.h1.chunked.pas  ← chunked writer/helper
```

H2/H3 相关单元目前仍是架构规划，不属于当前源码库存。

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
    Host: string;
    Port: UInt16;
    Path: string;
    Query: string;
    Fragment: string;
    class function Parse(const ARaw: string): TUrl; static;
    function ToString: string;
  end;
```

### 统一接口 (http.intf)

```pascal
type
  { 跨版本共享 }
  IHttpHeaders = interface
    procedure Set_(const AName, AValue: string);
    function Get(const AName: string): string;
    function Has(const AName: string): Boolean;
    procedure Del(const AName: string);
    function Count: Int32;
  end;

  IHttpRequest = interface
    function Method: THttpMethod;
    function Url: TUrl;
    function Version: THttpVersion;
    function Headers: IHttpHeaders;
    function Body: IReader;
    function ContentLength: Int64;
  end;

  IHttpResponse = interface
    function StatusCode: THttpStatus;
    function Headers: IHttpHeaders;
    function Body: IReader;
  end;

  IHttpResponseWriter = interface
    procedure WriteHeader(const AStatus: THttpStatus);
    function Headers: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
  end;

  { Handler — §8 三种回调形式 }
  THttpHandlerFunc = reference to procedure(const AReq: IHttpRequest; const AResp: IHttpResponseWriter);

  IHttpHandler = interface
    procedure ServeHTTP(const AReq: IHttpRequest; const AResp: IHttpResponseWriter);
  end;

  IHttpMiddleware = interface
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  { Router }
  IHttpRouter = interface(IHttpHandler)
    procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Use(const AMiddleware: IHttpMiddleware);
    procedure Group(const APrefix: string; const ASetup: THttpHandlerFunc);
  end;

  { Server }
  IHttpServer = interface
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

  { Client }
  IHttpClient = interface
    function Do_(const AReq: IHttpRequest): IHttpResponse;
    function Get(const AUrl: string): IHttpResponse;
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
  end;

  { Transport — 协议实现层接口 }
  IHttpTransport = interface
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  IHttpServerTransport = interface
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
  end;
```

### Server runtime ownership

- `nextpas.core.http.server` 不再拥有自己的通用 accept/thread runtime。
- 真实 listener / accept / shutdown / backend 选择由 `nextpas.core.net.server` 提供。
- `IHttpServerTransport` 是 per-connection protocol seam，不是整机 runtime seam。
- hijack / detach 这类 ownership 语义通过 `TTcpServerConnOwnership` 与 TCP foundation 对齐。

### 版本特有接口（不进 http.intf，留在各自 impl 内部）

- `IHttp1Upgrader` — WebSocket 升级
- `IHttp2Session` / `IHttp2Stream` — H2 流管理
- `IHttp3Session` — H3 会话

---

## 依赖关系

```
http.base       ← errors
http.intf       ← http.base, io.intf, net.intf
http.headers    ← http.base, text, collections
http.url        ← http.base, text
http.message    ← http.intf, http.headers, io
http.router     ← http.intf, collections
http.middleware ← http.intf
http.server     ← http.base, http.intf, net.base, net.intf, net.server, impl.registry
http.client     ← http.base, http.intf, io, text, impl.registry

impl.registry   ← http.base, http.intf, impl.h1
impl.h1.*       ← http.base, http.intf, net, io, text
impl.h2.*       ← http.intf, net, tls, io, collections
impl.h3.*       ← http.intf, quic, io, collections
```

---

## H1 Parser 策略

基于 llhttp（Node.js 官方 HTTP parser）：

- 用 c2pas888 项目翻译 llhttp C 源码为 Pascal
- 修正为 nextpas 框架风格（命名规范、异常处理）
- 放入 `nextpas.core.http.impl.h1.parser.pas`
- 对外通过 `IHttpServerTransport` 接口暴露

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
Benchmark：对照 Go net/http、Rust actix-web 的 hello-world QPS

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
