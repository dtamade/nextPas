# nextpas.core.http 代码契约

**模块路径**：`core/src/nextpas.core.http*.pas`（约 58 个源文件）
**层级**：L3（依赖 L0–L2：net, tls, json, io, text, …）
**Owner**：http worktree lane
**最后更新**：2026-07-16
**版本**：3.0

---

## 1. 模块边界

```
http.pas                 ← 统一门面（re-export）
http.base                ← THttpMethod/Status/Version, TUrl, options, EHttpError
http.intf                ← IHttp* 接口（Request/Response/Client/Server/Router/…）
http.message             ← THttpRequest/THttpResponse + helpers + THttpRequestBuilder
http.headers             ← IHttpHeaders 实现
http.url                 ← URL parse / encode helpers（base/TUrl 拥有核心类型）
http.router[+group]      ← radix router + path params + regex routes + groups
http.middleware.*        ← 中间件链与内建 middleware
http.client / server     ← facade 编排（server 委托 net.server）
http.static / websocket  ← helper 级公开面
http.form / cookie / sse ← 表单、Cookie、SSE 辅助
http.impl.registry       ← 版本 → transport factory
http.impl.h1.*           ← HTTP/1.x transport + parser/writer/chunked/fast
http.impl.h2.*           ← HTTP/2 frame/HPACK/stream/session/client/TLS
http.impl.tls.stream     ← TLS over TCP stream wrapper
http.fuzz                ← 模糊测试辅助（测试/安全验证用）
```

公开消费方默认只 `uses nextpas.core.http`。

---

## 2. 核心公开接口（与源码一致）

### 2.1 Server / Client

```pascal
IHttpServer = interface
  procedure ListenAndServe(const AAddr: string; const APort: UInt16);
  procedure Shutdown;
  function LocalAddr: TNetAddress;
  function IsRunning: Boolean;
end;

IHttpClient = interface
  function Send(const AReq: IHttpRequest): IHttpResponse;
  procedure CloseIdleConnections;
  function Get/Post/Put/Delete/Patch/Head/Options(...): IHttpResponse;
  function PostForm / PostJson / PutJson / PatchJson / DeleteJson(...): IHttpResponse;
  function SendStreaming(...): IHttpResponse;
  function WithBasicAuth / WithBearerAuth / WithHeader /
           WithTimeout / WithMaxRedirects / WithFollowRedirects /
           WithRetry(...): IHttpClient;
end;
```

### 2.2 Request / Response

- 公开类型是 **接口** `IHttpRequest` / `IHttpResponse`，不是裸 record wire 模型。
- 推荐构造：`THttpRequestBuilder`（fluent）。
- 旧 `NewRequest` / 部分 `NewStreamingRequest` overload 已 `deprecated 'Use THttpRequestBuilder instead'`。
- Body 通过 `IReader` 表达；固定 body helpers 会复制到内存 reader 并发布 `Content-Length`。
- Streaming：`NewStreamingRequest` + `SendStreaming` — Send 拥有并关闭 body；不可回放 body 遇 redirect 失败。

### 2.3 Router / Middleware

```pascal
IHttpRouter = interface(IHttpHandler)
  procedure Handle / Get / Head / Post / Put / Delete / Patch / Options / ...
  procedure HandleRegex / GetRegex / ...
  procedure Use(const AMiddleware: IHttpMiddleware);
end;

IHttpHandler = interface
  procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
end;

IHttpMiddleware = interface
  function Wrap(const ANext: IHttpHandler): IHttpHandler;
end;
```

- 404/405 默认走 RFC 7807 `HttpWriteErrorResponse`（`application/problem+json`）。
- 405 设置 `Allow` 列表；HEAD 可隐式回落到 GET 路由。

### 2.4 Transport seams

```pascal
IHttpTransport.RoundTrip(Req): Response
IHttpServerTransport.ServeConn(Conn, Handler): ownership
IHttpServerSessionFactory[.WithContext]
```

- `NewHttpClient([Transport][, Options])` / `NewHttpServer(Handler[, Transport][, Options])`
- 显式 transport 注入优先于 registry 默认解析。
- 内建：`hvHttp10`/`hvHttp11` → H1；`hvHttp2` → H2。默认版本 `hvHttp11`。
- Registry 初始化后冻结（`GFrozen`）；测试可经逃生口解冻。

---

## 3. 不变量

| ID | 内容 |
|----|------|
| INV-1 | H1 keep-alive 默认开启；`Connection: close` 后不复用 |
| INV-2 | H2 流 ID 奇偶分离（客户端奇 / 服务端偶） |
| INV-3 | HPACK 动态表受 `SETTINGS_MAX_HEADER_TABLE_SIZE` 约束 |
| INV-4 | chunked 以 0-size chunk 终止，可带 trailer section |
| INV-5 | H1 response parser 在 keep-alive 消息完成后 pause，保留未消费字节 |
| INV-6 | registry 冻结后不可改 |
| INV-7 | header 名大小写不敏感查找 |
| INV-8 | header 值拒绝 CR/LF/控制字符（允许 HTAB，RFC 9110 §5.5） |
| INV-9 | public HTTP contract 保持同步直线型，不泄漏 epoll/reactor 细节 |
| INV-10 | trailer 字段不污染普通请求 `Headers`；可保留 `Trailer:` 声明头 |
| INV-11 | 错误响应 helper 默认 RFC 7807 Problem Details |

---

## 4. 错误与生命周期

- 模块错误类型：`EHttpError`（及参数边界上的 `EArgumentError`）。
- Server runtime ownership：`nextpas.core.net.server`；HTTP 只拥有协议状态机。
- Client：idle pool 经 `CloseIdleConnections`；`Send` 拥有 close-capable request body。
- Redirect：`301/302/303` → GET 无 body；`307/308` 保方法；跨 authority 剥离敏感头。
- WebSocket：`UpgradeWebSocket`（server）/ `ConnectWebSocket`（client）；client 帧掩码。

---

## 5. 协议策略

### H1

- llhttp 翻译 parser + 保守 fast path
- chunked / keep-alive / Expect:100-continue / hijack
- threaded 正确性基线；Linux epoll poll-driven session 已落地

### H2

- 完整 transport：frame / HPACK / stream / session / client / TLS ALPN `h2`
- cleartext：prior knowledge only（无 h2c Upgrade）
- 设计排除：server push、CONNECT/WS-over-H2、PRIORITY 调度

### H3

- **未实现**；仅版本枚举 + registry seam
- 阻塞：独立 QUIC 模块

---

## 6. 测试门禁

主门禁：`core/tests/nextpas.core.http/Makefile`（34 suites）

纳入：base/url/headers/message/form/cookie/router/middleware(s)/hsts/static/
client/contract/registry/h1*/server/security/stress/h2*/websocket*/fuzz/https_redirect

旁路：benchmarks、examples、smoke、integration、tls_real（环境/性能/长集成）

单套件：

```bash
make focused FOCUS=core/tests/nextpas.core.http/test_http_router
```

---

## 7. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-07-01 | 1.0 | 初始 |
| 2026-07-06 | 2.0 | 对齐接口重写（仍混有旧 record 描述） |
| 2026-07-16 | 3.0 | 与真实 IHttp* 面、builder、H2、门禁清单对齐 |
