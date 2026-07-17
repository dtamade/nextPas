# nextpas.core.http 代码契约

**模块路径**：`core/src/nextpas.core.http*.pas`（约 58 个源文件）
**层级**：L3（依赖 L0–L2：net, tls, json, io, text, …）
**Owner**：http worktree lane
**最后更新**：2026-07-18（Wave I1 pool active health probe）
**版本**：3.15

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
  function GetString / GetBytes / PostString / PutString /
           PatchString / DeleteString(...): string or TBytes;  { ensure-2xx }
  function GetJson(...): IJsonDocument;  { ensure-2xx + JsonParse }
  function PostForm / PostMultipart(...): IHttpResponse;
  function PostJson / PutJson / PatchJson / DeleteJson(...): IHttpResponse;  { raw }
  function SendStreaming(...): IHttpResponse;
  function WithBasicAuth / WithBearerAuth / WithHeader /
           WithTimeout / WithConnectTimeout /
           WithMaxRedirects / WithFollowRedirects /
           WithRetry / WithCookieJar / WithProxyUrl /
           WithTLSContext(...): IHttpClient;
end;
```

**JSON 三层（raw vs ensure string vs ensure+decode）**：

| 形态 | API | 行为 |
|------|-----|------|
| raw | `IHttpClient.PostJson/PutJson/PatchJson/DeleteJson` | 返回 `IHttpResponse`，**不** ensure-2xx |
| ensure string | free-fn `HttpPostJson` / `HttpGetString` / 方法 `GetString`/`PostString`/… | ensure 2xx + body string（或 TBytes） |
| ensure+decode | free-fn `HttpGetJson` / `HttpPostJsonDocument` / `HttpPutJsonDocument` / `HttpPatchJsonDocument` / `HttpReadResponseJson` / 方法 `GetJson` | ensure 2xx + `JsonParse` → `IJsonDocument`；非法 JSON → `hekProtocol` Op=`json` |

**Content-Encoding（Wave C1）**：

| 侧 | API | 行为 |
|----|-----|------|
| server 响应压缩 | `CompressionMiddleware` / `CompressionMiddlewareWith` | 按 `Accept-Encoding` 选 gzip/deflate；默认最小 body 1024 |
| server 请求解压 | `DecompressMiddleware(AMaxSize)` | 请求 `Content-Encoding: gzip\|deflate` 解压；失败 → 400 |
| client raw body | `HttpReadResponseBodyBytes` / `String` / `StringAuto` | **不**自动解 Content-Encoding（wire 字节） |
| client 显式解码 | `HttpDecodeContentEncoding` / `HttpReadResponseBodyBytesDecoded` / `HttpReadResponseBodyStringDecoded` | 单 coding：`gzip`/`x-gzip`/`deflate`/`identity`/缺省；`AMaxSize>0` 限制解压输出 |
| 不支持编码 | 同上 | `hekProtocol` Op=`content_encoding`（含 multi-coding） |
| 损坏 payload | 同上 | `hekBody` Op=`content_encoding` |
| 非目标 | br / zstd / 浏览器完整 content 栈 / 默认自动 Accept-Encoding 协商 | 不在 C1；未支持编码诚实失败 |

**条件请求 / 静态缓存元数据（Wave C2）**：

| 能力 | 行为 |
|------|------|
| `ServeFile` / `ServeDir` / `ServeFileDownload` | 发布 strong `ETag`（`HttpMakeStrongETag(size, mtime_ns)`）、`Last-Modified`（**秒**精度）、`Cache-Control: public, max-age=0, must-revalidate` |
| `If-None-Match` | 与当前 ETag 精确匹配、`*`、或逗号列表命中 → **304** + ETag/Last-Modified；**优先于** `If-Modified-Since` |
| `If-Modified-Since` | 仅在无 `If-None-Match` 时生效；HTTP-date 可解析且资源 mtime_seconds ≤ 该时刻 → **304**；非法日期忽略（当 200） |
| 公开辅助 | `HttpIfNoneMatchMatches` / `HttpNotModifiedSince` / `HttpTryWriteNotModified`（自定义 handler 可复用 304 路径） |
| 304 体 | 无 body；helper 设 `Content-Length: 0` 便于 framing |
| 非目标 | 完整缓存策略、`If-Match`/`If-Unmodified-Since` 写路径、启发式过期、CDN 语义 |

**Range / 静态流式（Wave C3）**：

| 能力 | 行为 |
|------|------|
| `Accept-Ranges` | 200/206 成功静态响应发布 `Accept-Ranges: bytes` |
| 单段 `Range: bytes=start-end` / `start-` / `-suffix` | **206** + `Content-Range` + 精确 `Content-Length`；body 经 `CopyFileRange` 流式写出 |
| 越界 / 非法 / multi-range（含逗号） | **416** + `Content-Range: bytes */size` |
| 整文件路径 | `IFile` + `io.Copy`；**禁止** `ReadFile`/`ReadAll` 整文件进内存（source-contract 锁定） |
| 与条件请求 | 先评估 304；命中则不进入 Range |
| 非目标 | multipart ranges、`If-Range`、目录列表产品化、CDN 语义 |

### 2.2 Request / Response

- 公开类型是 **接口** `IHttpRequest` / `IHttpResponse`，不是裸 record wire 模型。
- 推荐构造：`THttpRequestBuilder`（fluent：Header / BasicAuth / BearerAuth /
  ContentType / Body / QueryParam / Timeout / MaxRedirects / FollowRedirects / Build）。
- **非 deprecated 工厂（仅 2 个）**：
  - `NewRequest(Method, TUrl)` — 最小原始工厂（测试/内部桥接仍可直接用）
  - `NewGetRequest(Path)` — 路径级 GET 便捷工厂
- **公开 request 工厂白名单（仅 2 个）**：
  - `NewRequest(Method, TUrl)` — 最小原始工厂
  - `NewGetRequest(Path)` — 路径级 GET 便捷工厂
  - 另保留 `NewRequest(Method, string)` 作为 URL 解析桥（不带 headers/body）
- 多参 `NewRequest` overload **已物理删除**；一律用 `THttpRequestBuilder`。
- `NewStreamingRequest` **已物理删除**；已知长度流式 body 用
  `THttpRequestBuilder.Body(IReader)+ContentLength` 或
  `IHttpClient.SendStreaming`。
- Body 通过 `IReader` 表达；固定 body helpers 会复制到内存 reader 并发布 `Content-Length`。
- Builder body 契约：
  - `Body(string|TBytes)`：按实际长度发布 `Content-Length`；**空 string** 仍是
    有 body + `Content-Length: 0`（与「未调用 Body」区分）。
  - `Body(IReader)` + **`ContentLength(N)`**：已知长度流式请求。
  - 仅 `Body(IReader)` 未声明长度 → **H1 chunked**（`ContentLength = -1`，
    发布 `Transfer-Encoding: chunked`）；**禁止**静默 `Content-Length: 0`。
  - `SendStreaming(..., ContentLength < 0)` 同样走 H1 chunked。
  - H2 拒绝未知长度 / chunked request body（`hekArgument`）。
- Streaming：`SendStreaming` — Send 拥有并关闭 body；不可回放 body 遇 redirect 失败。
- Client convenience `Post/Put/Patch/Delete` **仅** `string` / `TBytes` body 重载
  （**无** `IReader` 便捷 overload）。
- `WithRetry(N)`：对 **429**、**5xx 响应** 与 **`HttpErrorIsRetryable` 异常**
  （`hekTimeout` / `hekConnect` / 裸 `ETimeoutError` / `ENetworkError`）在
  最多 N 次额外尝试内重试。**不**重试其他 4xx。
  **退避**（cycle-8 + cycle-11）：若响应带可解析的 **delta-seconds** 或
  **IMF-fix HTTP-date** `Retry-After`，优先使用该延迟（**硬顶 60s**；
  过去日期 → 0ms）；否则指数退避（100ms 基、封顶 5s）。
  非法 `Retry-After` 回退指数退避。长 sleep 以 ~100ms 切片轮询 cancel。
  **幂等门闩**（与 H1/H2 pool retry 同一规则）：仅当
  `HttpIsRetrySafeRequest(Req)` 为真时才进入重试环——即 method ∈
  {GET, HEAD, OPTIONS, TRACE} **或** 请求带 `Idempotency-Key` /
  `X-Idempotency-Key`。非幂等（如裸 POST）即使 5xx/timeout/429 也只尝试一次。
  重试前若 body 可回放（`IStream`）则 rewind；非空且不可回放 body 不重试。
- 请求取消：`IHttpCancelToken`（**协作检查点**，非 OS 级硬中断）+
  `THttpRequestOptions` / builder / client 挂钩。
  **检查点清单**：
  1. `IHttpClient.Send` 入口
  2. redirect 跟进前
  3. `WithRetry` 退避前后
  4. H1 `RoundTrip`：入口、新 dial 前、request write 后 / response read 前
  5. pool reconnect 重写前
  取消抛 `EHttpError(hekCanceled)`。H1 client 在 dial 后把 cancel token
  接到 `ITcpStream.SetCancelToken`：`NewHttpCancelToken` 为 waitable
  （socketpair wake + `platform_socket_poll_or_wake`，Unix）；probe-only
  token 退回 ~10ms `SO_*TIMEO` 切片。中途取消抛 `hekCanceled`（经
  `ECancelledError` 包装）。
  **Windows residual（Wave R3）**：`platform_socket_pair` 在 Windows 路径
  固定返回 `PLATFORM_ERR_UNSUPPORTED`（无原生 socketpair；loopback 方案未
  落地）。`TNetCancelToken` 因此 `FHasWake=False`，`WakeHandle=0`，全程
  **probe-only**（~10ms `NET_IO_CANCEL_SLICE_MS`），**不**声称近即时唤醒。
  Linux/macOS/FreeBSD waitable 证据不变（X2）。
  **仍建议**与 `Timeout` / `WithTimeout` 配对，避免无 cancel 时无限等待。
  超时仍为 `hekTimeout`（`WithTimeout` / client options）。
- Client 超时拆分（`THttpClientOptions`）：
  - `Timeout`：socket 就绪后的 request 读/写 deadline（ms；0=无限）
  - `ConnectTimeout`：新 dial 时 **OS `connect()` + post-dial 首写** budget（ms）。
    `>0` 时经 `TcpConnect(host, port, ms)` 有界 dial，并作为首写 budget。
    `=0` 时 dial 回退到 `Timeout`（`Timeout>0` 则有界，否则无界）；首写用
    `Timeout`。
- **Production defaults（可用性纪律）**：
  - 生产 client：`THttpClientOptions.Default.Timeout` = **30000** ms；
    仍可用 `WithTimeout` 覆盖。`Timeout=0` 仅适合测试/特殊工具。
    默认 `Timeout` 也会作为 OS dial 上界（当 `ConnectTimeout=0`）。
  - **禁止**把“只挂 cancel、不设 Timeout”当作唯一生产模板（waitable 近即时；
    probe-only 仍有 ~10ms 切片上界）。
  - 生产 server：`THttpServerOptions.Default` 的 Read/Write timeout 仍为 **0**
    （兼容测试）；生产路径使用 **`THttpServerOptions.Production`**
    （Read/Write = 30000 ms）或显式 `WithReadTimeout` / `WithWriteTimeout`。
    IdleTimeout alone 不是完整生产模板。示例 `http_hello_server` /
    `http_websocket_echo_demo` 使用 Production。
  - 示例 `http_get_client` 使用有限 client timeout。

#### With* 链语义（Wave E2）

| 调用 | 机制 | 覆盖规则 | 注释 |
|------|------|----------|------|
| `WithTimeout(ms)` | **decorator** `TOptionsOverrideClient` | 合并到 per-request `TimeoutMs`；**外层（后链式调用）胜** | **不**改 `THttpClientOptions.Timeout` / `ConnectTimeout` |
| `WithMaxRedirects` / `WithFollowRedirects` | **decorator** 同上 | 同字段外层胜 | 请求级覆盖 client options |
| `WithRetry(N)` | **decorator** `TRetryClient` | 外层包装；可与 timeout/header 叠 | 见重试规则段 |
| `WithHeader` / `WithBasicAuth` / `WithBearerAuth` | **decorator** | 同名头/Authorization：**外层胜**（仅当尚未设置时写入） | Send 由外向内 |
| `WithCookieJar` | **decorator** | jar 外层保留；已有 Cookie 头不覆盖 | nil → `hekArgument` |
| `WithConnectTimeout(ms)` | **rebuild** `NewHttpClient(options)` | 写入 `THttpClientOptions.ConnectTimeout` | dial budget；`=0` 时 `EffectiveConnectTimeout` = `Timeout` |
| `WithProxyUrl` / `WithTLSContext` | **rebuild** 同上 | 写入 options 并重建 transport | 装饰器链经 `RebindInner` 重绑到新 base，**不丢**外层 auth/retry/header/timeout |
| 构造 `NewHttpClient(opts)` | base options | record `With*` 链式字段覆盖 | client `Default.Timeout=30000`；server 用 `Production` 非 `Default` |

**Timeout vs ConnectTimeout 分界**：

| 字段 | 作用阶段 | 0 含义 | 覆盖入口 |
|------|----------|--------|----------|
| `Timeout` | socket 就绪后 request 读/写 | 无界（仅测试/工具） | options / `WithTimeout` / builder / request options |
| `ConnectTimeout` | OS `connect` + 新连接首写 | 回退到 `Timeout`（`Timeout` 亦 0 则无界） | options / `WithConnectTimeout`（rebuild） |

**Default vs Production**：

| 载体 | Default | Production / 生产建议 |
|------|---------|----------------------|
| `THttpClientOptions` | `Timeout=30000`，`ConnectTimeout=0` | 保持 Default 或显式有限 `WithTimeout`；勿依赖 cancel-only |
| `THttpServerOptions` | Read/Write=**0**（测兼容） | **`Production`** Read/Write=30000；Idle  alone 不足 |
| `TWebSocketOptions` | ConnectTimeout=Timeout=30000 | 同 Default；`=0` 仅显式无界 |

### 2.2.0a Net-dependent capabilities

| Capability | HTTP surface today | Owner | Status |
|------------|-------------------|-------|--------|
| OS `connect()` dial timeout | `ConnectTimeout` / `Timeout` → `TcpConnect(..., ms)` | `nextpas.core.net` + H1/H2 dial | **Landed** (H1/H2) |
| Interruptible blocked socket read on cancel | waitable `NewNetCancelToken` / `NewHttpCancelToken` + poll-or-wake; probe-only ~10ms slice | net + H1/H2/WS client wire | **Landed** (X2); **Windows = probe-only only**（R3；`platform_socket_pair` → UNSUPPORTED） |
| WebSocket client dial / handshake budget | `TWebSocketOptions.ConnectTimeout` / `Timeout` (Default=30000) | http.websocket | **Landed** (cycle-5) |
| HTTPS CONNECT (plain HTTP proxy) | CONNECT + TLS over tunnel; origin-form | http H1 + TLS stream | **Landed** (cycle-9 Wave D) |
| H1 direct HTTPS | dial → TLS wrap → origin-form; pool `https\|host` | http H1 + TLS stream | **Landed** (cycle-10 Wave E) |
| Proxy authentication | `ProxyUrl` UserInfo → `Proxy-Authorization: Basic` only | http H1 | **Landed** (Wave E Basic + Wave I freeze) |

### 2.2.1 EHttpError taxonomy（Wave E1 + Wave J Op）

- `EHttpError` 保留**单一**异常类型；字段：`Kind` / 可选 `Status` / 可选 `Op`。
- `Create(string)` 仅兼容路径（`Kind = hekUnknown`，Category 默认 network）。
- 新代码优先 `Create(Kind, Message)`；热点失败路径用 `CreateOp` 填稳定 `Op`
  （metrics/日志友好）。`CreateOp(..., Status)` 在 `hekStatus` 保留 Status。
- **不**要求 Op-everywhere；`hekArgument` 前置条件通常不填 Op。

#### Kind 分类表

| Kind | Category | 含义 | 典型 Op / 备注 |
|------|----------|------|----------------|
| `hekUnknown` | ecNetwork | 仅 `Create(string)` 兼容 | 新代码禁止用 |
| `hekArgument` | ecInvalidArgument | 调用方前置条件、配置、消息形状 | 通常无 Op |
| `hekTimeout` | ecTimeout | 读/写/连接 deadline | `transport` |
| `hekConnect` | ecNetwork | dial / CONNECT / nil response / 传输连通 | `connect` `round_trip` `transport` `download` `websocket` |
| `hekProtocol` | ecNetwork | HTTP/应用层协议违规 | `transport` `content_encoding` `json` |
| `hekParse` | ecParse | 方法/URL/响应行等解析失败 | `transport` |
| `hekRedirect` | ecNetwork | 重定向策略失败 | `redirect` |
| `hekBody` | ecNetwork | body 读写/解码失败 | `redirect` `download` `content_encoding` `transport` |
| `hekUpgrade` | ecNetwork | WebSocket 升级协商失败 | 通常无 Op |
| `hekRegistry` | ecNetwork | transport registry | 通常无 Op |
| `hekStatus` | ecNetwork | ensure-2xx 非 2xx | `ensure` `download`（Status 保留） |
| `hekCanceled` | ecCancelled | 协作取消 | `cancel` `transport` |

#### 稳定 Op 命名表（Wave J；E1 对齐，不扩家族）

| Op | 典型 Kind | 边界 |
|----|-----------|------|
| `redirect` | hekRedirect / hekBody | client 重定向解析/回放 |
| `round_trip` | hekConnect | transport 返回 nil response |
| `transport` | hekTimeout / hekConnect / hekParse / hekProtocol / hekBody / hekCanceled | H1 RoundTrip 写读、wrap 裸 timeout/network/cancel |
| `connect` | hekConnect | proxy CONNECT 非 2xx（含 407） |
| `cancel` | hekCanceled | `IHttpCancelToken.ThrowIfCanceled` 检查点 |
| `ensure` | hekStatus | `HttpEnsureSuccess` 非 2xx（Status 保留） |
| `download` | hekConnect / hekStatus / hekBody | GetToWriter/File 路径 |
| `json` | hekProtocol | ensure+decode JSON 非法 body |
| `content_encoding` | hekProtocol / hekBody | 客户端 Content-Encoding：不支持编码 → hekProtocol；损坏 payload → hekBody |
| `websocket` | hekConnect | WS 升级/传输失败 |

#### 公开面纪律

- **消息形状错误**（非法/冲突 Content-Length、不支持 Transfer-Encoding、
  builder 非法 CL）→ `hekArgument`。
- **配置/nil 前置条件**（nil writer/client/router、负超时/负 max redirects、
  server/websocket/**SSE**/middleware 构造等）→ `hekArgument`。
- **禁止** `nextpas.core.http*` 公开路径 `raise EArgumentError` / 裸漏出
  `EArgumentError`；跨模块（如 compress）若抛 `EArgumentError`，边界包装为
  `EHttpError(hekArgument)`（middleware decompress 已包）。
- `HttpErrorIsUserError` 仍对**外来**裸 `EArgumentError` 返回 true（兼容），
  但 http 自身不制造该路径。
- **ensure-2xx / download / redirect 客户端错误消息**：在已知 method/URL 时
  前缀为 `METHOD url: detail`。`HttpEnsureSuccess` 无上下文与
  `(Resp, Method, Url)` 两形态；非 2xx → `Op=ensure`。
- Transport 边界：裸 `ETimeoutError` → `hekTimeout` + `Op=transport`；
  裸 `ECancelledError` → `hekCanceled` + `Op=transport`；
  裸 `ENetworkError` → `hekConnect` + `Op=transport`
  （H1/H2 RoundTrip 经 `HttpWrapTransportException`）。
  检查点 `HttpThrowIfCanceled` → `hekCanceled` + `Op=cancel`。
- 门面 helper：
  - `HttpErrorIsTimeout` / `HttpErrorIsRetryable`
  - `HttpErrorIsUserError` — `hekArgument` / `hekCanceled`（及兼容裸 `EArgumentError`）
  - `HttpIsRetrySafeRequest` / `HttpIsRetryableMethod` — 与 WithRetry / pool 共用
- Request body framing：known Content-Length **或** H1 chunked request body
  （未知长度）。`ContentLength < 0` 的非法值 fail-fast。

### 2.2.2 IHttpContext

- Context 附着在 **请求对象**（`IHttpRequestWithContext`），不使用进程级 pointer map。
- `SetValue` = 非拥有；`SetOwnedValue` = context 拥有并在覆盖/Remove/Destroy 时 Free。
- `Has(Key)` = 键存在（允许 value=nil 的非拥有条目）。
- 类型化 helper（门面 re-export）：`HttpContextGetString` / `HttpContextSetString` /
  `HttpContextGetInt64` / `HttpContextSetInt64`（内部 box 为拥有对象）。
- Middleware request 装饰基类 `THttpRequestWrapper` 转发
  `IHttpRequestWithContext` / `IHttpRequestWithOptions`，避免 bodycache/decompress
  等包装丢 `Supports` 保真。

### 2.2.3 CookieJar / Proxy（client 可用性）

- `IHttpCookieJar`：RFC 6265 最小存储；`NewHttpCookieJar` + client
  `WithCookieJar(Jar)` 在 Send 前注入 `Cookie`，在响应后吸收 `Set-Cookie`。
  默认 **无** jar（不隐式持久化）。
  **过期**：解析 `Max-Age`（优先）与 `Expires`（IMF-fix）；到期在
  `StoreFromResponse` / `CookieHeaderFor` 时淘汰；`Max-Age<=0` 删除匹配项。
  Session cookie（无过期属性）不自动淘汰。无磁盘持久化。
  **SameSite** + **SiteKey (eTLD+1)**：解析 `SameSite=Strict|Lax|None`；缺省按 **Lax**；
  `None` 必须带 `Secure` 否则不存储。SiteKey = 可注册域（eTLD+1）：默认单标签
  eTLD（`a.b.example.com` → `example.com`），并对可维护的 **multi-label public
  suffix 子集**（如 `co.uk`、`com.au`、`github.io`）取 eTLD+1（`a.foo.co.uk` →
  `foo.co.uk`）。公开 API：`HttpCookieSiteKey`。`Domain` 等于 public suffix
  （含单标签 TLD）时 **拒绝存储**（防 super-cookie）。`Domain` 必须 domain-match
  请求 host。同站发送全部匹配 cookie；当 cookie Domain 的 SiteKey ≠ 请求 host
  SiteKey 时仅发送 `SameSite=None`。客户端 jar **不**建模页面 initiator / 顶层
  站点上下文（无跨站子资源导航语义）；Domain 匹配仍是主过滤。
- HTTP proxy：`THttpClientOptions.ProxyUrl` **或** fluent
  `IHttpClient.WithProxyUrl`（重建 transport；装饰器 re-stack）。
  明文 `http://[user:pass@]host:port` 正向代理（proxy scheme 仅 `http`）。
  - 目标 `http://`：absolute-form request-line（不变）。
  - 目标 `https://`：对 proxy 发 `CONNECT host:port`，2xx 后对隧道
    `NewTlsClientTcpStream`（SNI=origin host，ALPN=`http/1.1`），再发
    origin-form 请求。非 2xx CONNECT → `hekConnect`。
  - **Proxy auth 产品冻结（Wave I）——仅 Basic**：
    - `ProxyUrl` 含 UserInfo 时注入 `Proxy-Authorization: Basic`
      （`Base64(UTF-8(raw UserInfo))`，不做 percent-decode）：
      CONNECT 必带；absolute-form 仅在请求未设置该头时注入。
    - **不**实现 Digest / NTLM / Negotiate challenge-response；**不**对
      `Proxy-Authenticate` 做 407 自动重试。
    - CONNECT 返回 **407** → `hekConnect`，消息明确「Basic only」。
    - absolute-form 返回 407 时作为普通响应 `StatusCode` 交给调用方（不自动重试）。
    - 需要非 Basic 方案：调用方自设 `Proxy-Authorization` 头（absolute-form）
      或改基础设施；不要期待 client 静默升级鉴权协议。
  - 可选 `THttpClientOptions.TLSContext`（nil → `TSSLQuick.SecureClient`），
    或 fluent `WithTLSContext` / `THttpClientOptions.WithTLSContext`（重建
    transport；nil 清除回 SecureClient 默认路径）。
  - Digest / NTLM / Negotiate / SOCKS：**Park**（见 ROADMAP Phase X）。
- H1 **直连 https**（无 proxy）：dial origin → `NewTlsClientTcpStream`
  （同 TLSContext/SecureClient，SNI=host，ALPN=`http/1.1`）→ origin-form；
  连接池键前缀 `https|` 与明文隔离。
- `PostMultipart(Url, Fields, Files)`：multipart/form-data 便捷 POST
  （自动 boundary + `EncodeMultipartFormData`）。
- `IHttpClient.GetString` / `GetBytes`：与 free function `HttpGetString` /
  `HttpGetBytes` 等价（ensure 2xx + body）。
- `IHttpClient.GetJson`：与 free function `HttpGetJson` 等价（ensure 2xx +
  `JsonParse` → `IJsonDocument`）。另提供 `HttpReadResponseJson` 从已有
  `IHttpResponse` ensure+decode。写路径 ensure+decode：
  `HttpPostJsonDocument` / `HttpPutJsonDocument` / `HttpPatchJsonDocument`
  （string 形态 `HttpPostJson` 等不变）。非法 JSON：
  `EHttpError(hekProtocol, Op=json)`。
- H1 默认 `User-Agent: nextpas-http/1.0`（请求未设置 `User-Agent` 时注入）。

### 2.2.3b WebSocket client connect budgets（cycle-5）+ cancel（cycle-7）

- `TWebSocketOptions.Default`：`ConnectTimeout = 30000`，`Timeout = 30000`
  （与 HTTP client production discipline 对齐）；**无**默认 CancelToken。
- `ConnectTimeout`：OS dial budget → `TcpConnect(host, port, ms)` when >0。
  `=0` 时 dial 回退到 `Timeout`（仍为 0 则无界 dial）。
- `Timeout`：upgrade handshake 读/写 deadline；成功 101 后清除，便于长连接帧 I/O。
- fluent：`WithConnectTimeout` / `WithTimeout` / **`WithCancelToken`** on options record。
- **Cancel（cycle-7 Wave B）**：
  - `WithCancelToken(IHttpCancelToken)` 挂协作取消；dial 后与握手、mid-frame
    `ReadFrame`/`Write*` 路径生效。
  - 有 `ITcpStream` 时：`SetCancelToken` + waitable wake（与 H1/H2 client 同路径）。
  - 入口 `HttpThrowIfCanceled`：token 已 cancel 时立即 `hekCanceled`（无需等切片）。
  - 成功 101 后 **保留** cancel、**清除** handshake deadline。
  - Close/Destroy 清除 stream cancel token。
- 传输错误经 `HttpWrapTransportException` → `hekTimeout` / `hekConnect` /
  `hekCanceled`，Op=`transport`（wrap）或 `websocket`（连接/升级失败 CreateOp）。
- 入口 `HttpThrowIfCanceled`：`hekCanceled` Op=**`cancel`**（与 HTTP client 共用 token 语义；非 `websocket`）。
- 显式 `ConnectTimeout=0` + `Timeout=0` 才恢复无界 dial（测试/特殊工具）。

### 2.2.3c WebSocket lifecycle（Era 6 Wave X1）

公开面：`UpgradeWebSocket` / `ConnectWebSocket` → `IWebSocket`。

| 阶段 | 行为 | 错误 / 证据 |
|------|------|-------------|
| Open | 101 后 `IsOpen=True`；成功握手清除 handshake deadline，**保留** cancel token | upgrade/client focused |
| Read | `ReadFrame` / `ReadMessage`；Ping 自动 Pong；分片聚合 | RFC 边角 suite |
| Write | `WriteText` / `WriteBinary` / `Ping` / `Pong`；控制帧 payload ≤125 | outgoing reject tests |
| Local `Close(code, reason)` | 幂等：已 `FCloseSent` 则 no-op；校验 code/reason UTF-8；发送 close 帧；`FOpen=False`；清 stream cancel | X1 lifecycle + CloseFrame |
| Peer close 帧 | `FCloseReceived=True` → `IsOpen=False`；仍可用 `Close`（`WriteFrameRaw`）回 close | CloseFrame echo |
| `IsOpen` | `FOpen and not FCloseSent and not FCloseReceived` | X1 lifecycle |
| 关闭后 Read | `hekProtocol`（`connection closed`） | X1 lifecycle |
| 关闭后 Write\* | `hekProtocol`（`connection closed`）；**不**经 `WriteFrame` 的 final `Close` 除外 | X1 lifecycle |
| Cancel | token 已 cancel → 入口/mid-frame `hekCanceled`；Close/Destroy 清 stream cancel | client cancel test |
| Upgrade 失败 | `hekUpgrade` / `hekArgument` / `hekConnect` 等；**不**写 500 到已 hijack 连接 | UpgradeException ownership test |
| 所有权 | `IWebSocket` 持有 hijack 后的 stream；server handler 异常不得再写 HTTP 500 到已升级连接 | ownership focused |
| **permessage-deflate（Era 8 I2）** | `TWebSocketOptions.EnablePermessageDeflate` 默认 **False**（opt-in）；`WithEnablePermessageDeflate`。握手：`Sec-WebSocket-Extensions: permessage-deflate; client_no_context_takeover; server_no_context_takeover`。仅双方都同意时 `FDeflateEnabled`。写路径：数据帧可设 RSV1 + raw DEFLATE（`RawDeflateMessageCompress`，无 context takeover）；不缩小则发明文。读路径：RSV1 解压，输出受 `MaxMessageSize` 约束。未协商却见 RSV1 → `hekProtocol`。 | websocket + websocket_client focused |

**毕业判定（production-helper）**：上表 + focused 全绿 + WS 路径 heaptrc 0 unfreed；**不是**子系统拆分。

**仍 Park**：WS-over-H2；子协议全家桶；新无关 Options 家族。

### 2.2.4 IHttpResponse metadata + Close

```pascal
IHttpResponse = interface
  property StatusCode: THttpStatus;
  property Headers: IHttpHeaders;
  property Body: IReader;
  property FinalUrl: string;      { post-redirect request URL; empty if synthetic }
  property Version: THttpVersion; { final-hop protocol; H1 from status-line, H2=hvHttp2 }
  procedure Close;
end;
```

- **FinalUrl**（Wave H）：`IHttpClient.Send` / 便捷方法在**最终**响应上盖章为产生该响应的请求 URL（`TUrl.ToString`）。`FollowRedirects` 开启时为最后一跳 URL，不是初始请求 URL。合成 `NewResponse` / 非 `THttpResponse` mock 的 FinalUrl 为空。
- **Version**（Wave H）：传输层写入。H1 来自 status-line 解析（`hvHttp10` / `hvHttp11`）；H2 `BuildResponse` 固定 `hvHttp2`。合成 `NewResponse` 默认 `hvHttp11`。
- **不做**：TLS 摘要、`Request` 回指、ContentLength 字段、transport 句柄泄漏到公开面。
- `Close` 语义对齐 `HttpReleaseResponseBody`（幂等）；析构时若未 Close 则自动 Close。
- 调用方应先读完 body 再让 response 离开作用域，或显式 `Close` / Read helper。

### 2.2.4 FPC RTL 隔离（可用性修复）

- 生产 HTTP 源与 examples/tests：**禁止**直接 `uses SysUtils` / `Process` /
  `BaseUnix`（仅 `nextpas.core.system` 可直接依赖 FPC RTL）。
- 子进程：`nextpas.core.process`（`Command` / `IChild`）；文本：`text.conv`；
  环境：`os.env`；路径/文件：`path` / `fs`。

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

- 模块错误类型：公开前置条件、transport 构造/入口前置条件与协议故障以
  **`EHttpError`** 为主（`hekArgument` / `hekTimeout` / …）。H1/H2/TLS stream
  的 nil conn/req/handler 等前置条件亦为 `hekArgument`（不再裸
  `EArgumentError`）。`HttpErrorIsUserError` 仍兼容框架 `EArgumentError` 与
  `hekArgument` / `hekCanceled`。
- Server runtime ownership：`nextpas.core.net.server`；HTTP 只拥有协议状态机。
- Client：idle pool 经 `CloseIdleConnections`；`Send` 拥有 close-capable request body。
- Redirect：`301/302/303` → GET 无 body；`307/308` 保方法；跨 authority 剥离敏感头。
- WebSocket / SSE：`UpgradeWebSocket` / `ConnectWebSocket`；`StartSSE` —
  公开前置条件均为 `hekArgument`。

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

#### H2 production edges（Wave A1）

| 边角 | 行为 | 证据 / residual |
|------|------|-----------------|
| Client GOAWAY 消费 | 响应完成后再见 GOAWAY → 连接 `IsReusable=false` 不入池；**响应未完成**时收到 GOAWAY → `hekProtocol`（`HTTP/2 GOAWAY received during response`） | `test_http_h2_client` GOAWAY / mid-response |
| Server GOAWAY | 停止新流；split last-stream tracking；peer GOAWAY 不覆盖 last seen peer id | `test_http_h2_session` GOAWAY 套件 |
| 流控 | 双向 WINDOW_UPDATE；发送窗耗尽等 peer update；连接级 flush pending update | client/session window tests |
| MaxConcurrentStreams | server 超限 → `REFUSED_STREAM` RST | session enforcement tests |
| 池 / 多路表征 | client **同步** `RoundTrip`：单连接上**串行**一流；池按 authority/`MaxPoolSize` 复用连接；**不**提供同连接并发多 `RoundTrip` 多路 API | pool tests + 本表 residual |
| Server push | `ENABLE_PUSH=0`；`PUSH_PROMISE` → GOAWAY `PROTOCOL_ERROR` | client SETTINGS + PUSH tests |
| TLS H2 | ALPN `h2`；`http://` prior knowledge；无 h2c Upgrade | facade / tls_real |

**诚实 residual（非缺口伪装）**：

- 公开 `IHttpClient` 不暴露“单连接并发多请求”多路 API；多请求并发依赖多连接或上层调度。
- OpenSSL backend heaptrc（**Wave X4 + R2 dig + R4 fix**）：
  - X4 修 `FPinValidator` 未释放（每 `CreateContext` ~32B → FreeAndNil）。
  - R2 曾诚实 Park **1×41B**（heaptrc size 41、无帧；process-lifetime）。
  - **R4**：根因 = `TOpenSSLLibrary.InvalidateCapabilitiesCache` 对含
    `BackendVersion: string` 的 `TSSLBackendCapabilities` 使用 `FillChar`，
    在 library `Finalize` 时 orphan 版本串（内容 `OpenSSL x.y.z …`）。
    修为 `FCapabilitiesCache := Default(TSSLBackendCapabilities)`（及同模式
    其它 backend）。`test_http_client` HTTPS 全量路径 **0 unfreed**。
- Cancel 平台分叉（**Wave R3**）：Unix waitable（socketpair+poll）；Windows
  `platform_socket_pair` = UNSUPPORTED → **仅 probe-only ~10ms**。见 §2.2.0 /
  §2.2.0a。
- H3 / QUIC：无产品需求 + Blocked on QUIC；禁止空 facade。h2c Upgrade、CONNECT/WS-over-H2：Park（见 ROADMAP）。

#### Client connection pool（Wave A2）

| 语义 | 行为 | 证据 |
|------|------|------|
| Pool key / authority | H1：canonical host + port（`https\|` / `connect\|` / proxy+target 变体编码进 key）；H2：host + port + secure | H1/H2 pool reuse tests |
| `MaxPoolSize` | **每 authority 最大空闲连接数**（默认 64）；**不是**跨 host 全局上限 | `test_http_client` / `test_http_h2_client` per-authority |
| Idle put | 仅 keep-alive / `IsReusable` 连接入池；超 per-authority 上限则关闭新归还连接 | pool max / non-reusable tests |
| Idle clear | `IHttpClient.CloseIdleConnections` → transport `IHttpTransportIdleConnections.CloseIdleConnections` 清空全部 authority 的空闲项；destroy 亦 `PoolClear` | CloseIdle + destroy source-contract |
| `IdleTTL` | 墙钟空闲淘汰（默认 **90000** ms）；`WithIdleTTL` 外层胜；**0** = 关闭墙钟淘汰；负值 `hekArgument`；借出/归还路径淘汰过期项（`IdleAtMs` 在 put 时打戳） | `test_http_client` IdleTTL expires / IdleTTL=0 keep；H1/H2 同源实现 |
| 主动健康探测（Wave I1） | **借出路径**（`PoolGet`，锁外）：H1 非阻塞 `TryRead` 探针（WouldBlock=活；数据/EOF/错误=丢弃）；H2 在读缓冲空时发 PING，等 ACK（`PingTimeout` 默认 5000ms；**0**=关闭 PING 探针，仅状态位）；失败连接 Close 后继续取池或 dial | `test_http_client` H1 probe source-contract；`test_http_h2_client` PING on borrow / discard closed / PingTimeout=0 |
| 并发模型 | 同步 `RoundTrip` 串行一流；同 transport 可多线程各自 RoundTrip（池 mutex）；**无**同连接多路 API | A1 residual |

#### H1 / H2 选择策略（Wave A2）

| 规则 | 行为 |
|------|------|
| 默认 | `THttpClientOptions.Default` → `UseRegistryVersion=True` → registry `GetDefaultClientVersion` = **`hvHttp11`** |
| 钉版本 | `WithVersion(hvHttp2)` / `WithVersion(hvHttp11)` 设 `UseRegistryVersion=False`，构造时 `ResolveClientTransport` 选 factory |
| 无自动升级 | **不会**在 H1 client 上因 ALPN 自动切到 H2；版本在 **client 构造时**选定 |
| H2 HTTPS | ALPN 必须协商 `h2`，否则 `hekProtocol` |
| H2 cleartext | prior knowledge only（`http://`）；无 h2c Upgrade |
| H3 | 未注册 factory；`Resolve*Transport(hvHttp3)` → `hekRegistry`；Blocked on QUIC |

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
| 2026-07-16 | 3.6 | Usability wave-2：hekTimeout wrap、hekArgument 消息形状、IReader fail-fast、THttpRequestWrapper、RTL isolation |
| 2026-07-16 | 3.7 | Usability wave-3：WithRetry=5xx+IsRetryable；connect wrap；删 IReader client overload；known-CL only；删 NewStreamingRequest；多参 NewRequest 仍 deprecated；decorator forwarder |
| 2026-07-17 | 3.8 | cycle-8 Wave C：`GetJson`/`HttpReadResponseJson` ensure+decode；`WithRetry` 支持 429 + delta-seconds Retry-After（cap 60s） |
| 2026-07-17 | 3.9 | cycle-11 Wave F：HTTP-date Retry-After；`WithTLSContext`；`HttpPost/Put/PatchJsonDocument` ensure+decode |
| 2026-07-17 | 3.10 | Wave C1：Content-Encoding 契约；client `HttpDecodeContentEncoding` / `HttpReadResponseBody*Decoded`；Op=`content_encoding`；server Compression/Decompress middleware 已落地 |
| 2026-07-17 | 3.11 | Wave C2：条件请求 helper + ServeFile 304 契约表（If-None-Match / If-Modified-Since） |
| 2026-07-17 | 3.12 | Wave C3：Range 单段/416/`Accept-Ranges` + 流式契约 |
| 2026-07-17 | 3.13 | Era 6 Excellence：cancel/OpenSSL/idle-TTL residual 标明 X2/X4/X3 可主动收敛；H3 无产品需求 |
| 2026-07-17 | 3.14 | Wave X1：WebSocket lifecycle 表（Close/`IsOpen`/关闭后读写/cancel Op） |
| 2026-07-17 | 3.15 | Wave X2：waitable cancel 唤醒（socketpair+poll）；probe-only ~10ms residual |
| 2026-07-17 | 3.16 | Wave R1：H1/H2 pool Close 锁外，IdleTTL suite 稳定 |
| 2026-07-17 | 3.17 | Wave R2：HTTPS 1×41B dig → 无可靠 call stack，诚实 process-lifetime residual |
| 2026-07-17 | 3.18 | Wave R3：Windows cancel = probe-only only（socket_pair UNSUPPORTED） |
| 2026-07-18 | 3.19 | Wave R4：HTTPS 1×41B 清零 — capabilities cache `Default` 替代 `FillChar` |
