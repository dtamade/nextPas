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
- 推荐构造：`THttpRequestBuilder`（fluent：Header / BasicAuth / BearerAuth /
  ContentType / Body / QueryParam / Timeout / MaxRedirects / FollowRedirects / Build）。
- **非 deprecated 工厂（仅 2 个）**：
  - `NewRequest(Method, TUrl)` — 最小原始工厂（测试/内部桥接仍可直接用）
  - `NewGetRequest(Path)` — 路径级 GET 便捷工厂
- 其余 `NewRequest` / 全部 `NewStreamingRequest` overload 均
  `deprecated 'Use THttpRequestBuilder instead'`；门面与 `message.pas` 必须同标记
  （`test_http_contract` source-contract 锁住）。
- Body 通过 `IReader` 表达；固定 body helpers 会复制到内存 reader 并发布 `Content-Length`。
- Builder body 契约（可用性修复后）：
  - `Body(string|TBytes)`：按实际长度发布 `Content-Length`；**空 string** 仍是
    有 body + `Content-Length: 0`（与「未调用 Body」区分）。
  - `Body(IReader)` + **`ContentLength(N)`**：已知长度流式请求；`Build` 调用
    `NewRequest(..., Reader, N)`。
  - 仅 `Body(IReader)` 未声明长度 → **`Build` fail-fast**（`EArgumentError`），
    **禁止**静默 `Content-Length: 0`。
  - 未知长度 / 不可回放流：走 `SendStreaming`（不经 builder 假装已知 CL）。
- Streaming：`NewStreamingRequest` + `SendStreaming` — Send 拥有并关闭 body；不可回放 body 遇 redirect 失败。

### 2.2.1 EHttpError.Kind（可用性修复）

- `EHttpError` 保留单一异常类型；增加 `THttpErrorKind`（Timeout/Connect/Protocol/
  Parse/Redirect/Body/Upgrade/Registry/Status/…）与 `Kind` / 可选 `Status` / `Op`。
- `Create(string)` 保持兼容（`Kind = hekUnknown`，Category 仍默认 network）。
- 新代码优先 `Create(Kind, Message)`；调用方可 `except on E: EHttpError` 后匹配 Kind。

### 2.2.2 IHttpContext（可用性修复）

- Context 附着在 **请求对象**（`IHttpRequestWithContext`），不使用进程级 pointer map。
- `SetValue` = 非拥有；`SetOwnedValue` = context 拥有并在覆盖/Remove/Destroy 时 Free。
- `Has(Key)` = 键存在（允许 value=nil 的非拥有条目）。

### 2.2.3 IHttpResponse.Close（可用性修复）

- `Close` 语义对齐 `HttpReleaseResponseBody`（幂等）；析构时若未 Close 则自动 Close。
- 调用方应先读完 body 再让 response 离开作用域，或显式 `Close` / Read helper。

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
| INV-12 | Keep-alive request-tail 见 §3.1（final public contract，非 provisional truth） |

### 3.1 Keep-Alive Request-Tail（INV-12，2026-07-16 定稿）

H1 server 对同连接上“当前请求 framing 完成后的未消费字节”采用 **request isolation + deferred follow-up parse**，而不是“首请求成功后立刻因尾巴拒整连接”或“把尾巴并进当前请求”。

#### A. `Connection: close` 请求

| 输入 | 契约 |
|------|------|
| `Content-Length` body 结束后仍有 extra bytes | **同请求** parser error → 显式 `400`，**不进入** handler |
| chunked terminal chunk 结束后仍有 extra bytes | **同请求** parser error → 显式 `400`，**不进入** handler |

#### B. Keep-alive 请求（默认 / 非 close）

适用范围：fixed-length（`Content-Length`）、plain chunked、trailer-complete chunked。

1. **Framing 完成即交付**
   当前请求在 framing 完成时立刻完成并进入 handler；handler 只看到本请求声明长度/解码后的 body。
2. **Tail 隔离**
   未消费字节进入连接级 pending buffer（`TH1ServerConnectionState.FPending`），**不得**污染当前 method/url/headers/body。
3. **合法 pipeline**
   同 write / 后续 write 中的完整下一请求按序处理；首响应与次请求响应保持 wire 顺序。
4. **Partial follow-up 不得早拒**
   半截 follow-up request-line / headers 在连接仍可继续读时，**不得**提前当成 malformed；补齐后可成为合法第二请求。
5. **Follow-up 400 时机**
   仅当 follow-up **结论性 malformed**，或 peer half-close / EOF 使 follow-up 截断无法完成时，才对 **follow-up** 返回显式 `400`（排在先前成功响应之后）。
6. **Garbage tail**
   framing 完成后的垃圾字节（非合法 HTTP 请求起始）→ 首请求仍 `200`（若合法）→ follow-up `400`。

#### C. 明确拒绝的收紧方案（不做）

- 不因 keep-alive 尾巴把 **已完整 framing 的首请求** 改成同请求 `400`
- 不在 partial follow-up 仍可能补全时主动“猜测拒绝”
- 不把该契约泄漏为 public async/callback API

#### D. 证据层

| 层 | 套件 | 锁什么 |
|----|------|--------|
| parser | `test_http_h1parser` | 只消费首请求；partial 可补全；pipeline 不污染 |
| server | `test_http_server` | handler body 边界；follow-up `400`；threaded + epoll |
| security | `test_http_security` | raw-wire safe-handling / wire-order |

状态：**final public contract**（不再记为 transport current truth）。

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
- keep-alive request-tail：INV-12（isolation + deferred follow-up parse）
- threaded 正确性基线；Linux epoll poll-driven session 已落地

### H2

- 完整 transport：frame / HPACK / stream / session / client / TLS ALPN `h2`
- cleartext：prior knowledge only（无 h2c Upgrade）
- 设计排除：server push、CONNECT/WS-over-H2、PRIORITY 调度

### H3

- **未实现**；仅版本枚举 + registry seam（`hvHttp3` / `HttpVersionToStr`）
- 内建 `RegisterBuiltins` **不**注册 H3 client/server factory
- 未注册时 `Resolve*Transport(hvHttp3)` → `EHttpError`（`test_http_registry`）
- 阻塞：独立 QUIC 模块（连接/流/TLS）；禁止空 H3 facade

---

## 6. 测试门禁

主门禁：`core/tests/nextpas.core.http/Makefile`（35 suites）

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
| 2026-07-16 | 3.1 | 定稿 INV-12 keep-alive request-tail final public contract |
| 2026-07-16 | 3.2 | H2 facade E2E 门禁 `test_http_h2_facade`；session write-drain 死锁修复 |
| 2026-07-16 | 3.3 | P3 API audit：facade/message deprecation 对齐；builder-first 清单 |
| 2026-07-16 | 3.4 | P4 成本隔离阶梯 + HTTP benches SysUtils 隔离修复 |
| 2026-07-16 | 3.5 | P5 H3 honesty：无内建 H3 factory；QUIC 阻塞显式化 |
