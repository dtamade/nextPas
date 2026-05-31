# nextpas.core.http 模块架构设计

## 概述

HTTP 模块是 L3 框架层的核心模块，提供 HTTP 服务器和客户端能力。
采用统一门面 + 协议实现隔离的架构，支持 HTTP/1.1、HTTP/2、HTTP/3 三个版本。

消费方只需 `uses nextpas.core.http` 即可获得完整能力，协议版本协商透明。

---

## 架构分层

```
┌─────────────────────────────────────────────────────────┐
│  门面层 (nextpas.core.http)                              │
│  统一 re-export，消费方唯一入口                          │
├─────────────────────────────────────────────────────────┤
│  应用层（跨版本共享）                                    │
│  Request / Response / Headers / Router / Middleware      │
│  Server 骨架 / Client 骨架                              │
├─────────────────────────────────────────────────────────┤
│  协议实现层（版本隔离）                                  │
│  impl.h1: 文本协议、chunked、keep-alive、upgrade       │
│  impl.h2: 二进制帧、多路复用、HPACK、流控、ALPN        │
│  impl.h3: QUIC 帧、QPACK、0-RTT、Alt-Svc             │
├─────────────────────────────────────────────────────────┤
│  impl.registry: 协议版本注册 + 自动协商                 │
├─────────────────────────────────────────────────────────┤
│  依赖层                                                  │
│  H1/H2: net (TCP) + tls (ALPN)                          │
│  H3: quic (独立 L2 sibling 模块)                        │
└─────────────────────────────────────────────────────────┘
```

---

## 文件结构

```
src/
  { 门面 + 公共层 }
  nextpas.core.http.pas                  ← 统一门面（re-export）
  nextpas.core.http.base.pas             ← 公共类型
  nextpas.core.http.intf.pas             ← 统一接口
  nextpas.core.http.message.pas          ← Request/Response 实现
  nextpas.core.http.headers.pas          ← Header 集合（解析/序列化/查找）
  nextpas.core.http.url.pas              ← URL 解析（scheme/host/path/query/fragment）
  nextpas.core.http.router.pas           ← Radix tree 路由 + 路径参数
  nextpas.core.http.middleware.pas       ← 中间件链
  nextpas.core.http.server.pas           ← Server 骨架（accept loop + handler dispatch）
  nextpas.core.http.client.pas           ← Client 骨架（连接池 + 重定向 + 超时）

  { 协议注册 }
  nextpas.core.http.impl.registry.pas    ← 协议版本注册表 + 自动协商

  { HTTP/1.1 实现 }
  nextpas.core.http.impl.h1.pas          ← H1 transport 入口
  nextpas.core.http.impl.h1.parser.pas   ← H1 协议解析（基于 llhttp 翻译）
  nextpas.core.http.impl.h1.writer.pas   ← H1 响应序列化
  nextpas.core.http.impl.h1.conn.pas     ← H1 连接管理（keep-alive）
  nextpas.core.http.impl.h1.upgrade.pas  ← H1 协议升级（WebSocket）

  { HTTP/2 实现 }
  nextpas.core.http.impl.h2.pas          ← H2 transport 入口
  nextpas.core.http.impl.h2.frame.pas    ← H2 帧编解码
  nextpas.core.http.impl.h2.hpack.pas    ← HPACK 头部压缩
  nextpas.core.http.impl.h2.stream.pas   ← H2 流管理 + 流控
  nextpas.core.http.impl.h2.conn.pas     ← H2 连接（多路复用）

  { HTTP/3 实现 }
  nextpas.core.http.impl.h3.pas          ← H3 transport 入口
  nextpas.core.http.impl.h3.frame.pas    ← H3 帧编解码
  nextpas.core.http.impl.h3.qpack.pas    ← QPACK 头部压缩
  nextpas.core.http.impl.h3.stream.pas   ← H3 流管理
  nextpas.core.http.impl.h3.conn.pas     ← H3 连接

  { QUIC（独立 L2 模块，非 http 子模块） }
  nextpas.core.quic.pas                  ← QUIC 门面
  nextpas.core.quic.base.pas
  nextpas.core.quic.intf.pas
  nextpas.core.quic.conn.pas
  nextpas.core.quic.stream.pas
  nextpas.core.quic.crypto.pas
```

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
    procedure ServeConn(const AConn: ITcpStream; const AHandler: IHttpHandler);
  end;
```

### 版本特有接口（不进 http.intf，留在各自 impl 内部）

- `IHttp1Upgrader` — WebSocket 升级
- `IHttp2Session` / `IHttp2Stream` — H2 流管理
- `IHttp3Session` — H3 会话

---

## 依赖关系

```
http.base       ← 无依赖（纯类型）
http.intf       ← http.base, io.intf, net.intf
http.headers    ← http.base, text, collections
http.url        ← http.base, text
http.message    ← http.intf, http.headers, io
http.router     ← http.intf, collections
http.middleware ← http.intf
http.server     ← http.intf, net, time, thread
http.client     ← http.intf, net, time, tls

impl.registry   ← http.intf
impl.h1.*       ← http.intf, net, io, text
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
+ impl.h1.parser (llhttp) + impl.h1.writer + impl.h1.conn
```

依赖：net, io, text, time, thread
测试：完整接口覆盖 + echo server + client round-trip + router dispatch
Benchmark：对照 Go net/http、Rust actix-web 的 hello-world QPS

### Phase 2: HTTP/2

```
+ impl.h2.frame + impl.h2.hpack + impl.h2.stream + impl.h2.conn
+ impl.registry (ALPN 协商)
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
6. **H2/H3 不污染 H1** — 条件编译或独立链接单元
7. **Router 内建** — 不需要第三方路由库（Radix tree，O(path_length)）
