# nextpas.core.http 代码契约

**模块路径**：`core/src/nextpas.core.http*.pas`（**101** 个生产源文件：92 + pool/retry/defense/tail/timeout 9；主 gate PROJECTS=**47**，含 mem/stream/sse + Era3 theme suites）
**层级**：L3（依赖 L0–L2：net, tls, json, io, text, …）
**Owner**：http worktree lane
**最后更新**：2026-09-04（文件数 92→**101**：pool/retry/defense/tail/timeout 五域四件套兑现 + taxonomy 正序 + 超时策略薄模块）
**版本**：3.55
**拆分优雅度**：单一 CONTRACT 约 **900** 行聚合池/重试/DoS/Keep-Alive/超时/门禁已按 **§1.1 六域四件套兑现拆分**；本版将 `pool`/`retry`/`impl.h2.defense`/`impl.h1.framing.tail`/`timeout` 薄模块落地 + `bytes.ops` 单源 + 热点 `inline`/零拷贝 + `PoolClear`/`Close` 资源释放不丢（见 §1.1 证据链）；**主文档瘦身为索引-锚点**（§2–§6 仅保留语义摘要 + 指向 `pool.md`/`retry.md`/`h2defense.md`/`tail.md`/`timeout.md`/`gating.md`，消双重维护）。

---

## 概要

HTTP 运行时:服务端与客户端,含 WebSocket 客户端、SSE、multipart、代理与 Cookie 支持;L3 依赖 net/tls/json/io/text(**101** 个生产源文件：原 92 + pool/retry/defense/tail/timeout 9 增量；门面仍聚合，§1.1 六域四件套已兑现，主文档瘦身为索引-锚点）。

## 1. 模块边界

```
http.pas                 ← 完整门面（re-export；含产品 middleware 全家桶）
http.minimal             ← 薄门面：base/intf/headers/url/router/message + server/client + chain 原语
http.base                ← THttpMethod/Status/Version, TUrl, options, EHttpError
http.intf                ← IHttp* 接口（Request/Response/Client/Server/Router/…）
http.message             ← THttpRequest/THttpResponse + helpers + THttpRequestBuilder
http.headers             ← IHttpHeaders 实现
http.url                 ← URL parse / encode helpers（base/TUrl 拥有核心类型）
http.router[+group]      ← radix router + path params + regex routes + groups
http.middleware          ← 链原语（HandlerFunc / MiddlewareFunc / Chain）
http.middleware.*        ← 内建产品 middleware（cors/recovery/logger/…）
http.client / server     ← facade 编排（server 委托 net.server）
http.static / websocket  ← helper 级公开面
http.websocket.room      ← 房间语义（Join/Leave/Broadcast + 有界管理器，IWebSocketRoom）
http.form / cookie / sse ← 表单、Cookie、SSE 辅助
http.impl.registry       ← 版本 → transport factory
http.impl.cancel.adapter ← 共享 IHttpCancelToken → INetCancelToken 桥（h1/h2/websocket）
http.impl.h1.*           ← HTTP/1.x transport + parser/writer/chunked/fast + poll/serve
http.impl.h2.*           ← HTTP/2 frame/HPACK/stream/session/client(+body)/TLS
http.impl.tls.stream     ← TLS over TCP stream wrapper
{ tests only } support/nextpas.core.http.fuzz ← 模糊测试辅助（非生产 inventory）
```

| 入口 | 何时用 |
|------|--------|
| `uses nextpas.core.http.minimal` | 只要类型 + router + server/client + HandlerFunc/Chain，不要 cors/recovery/… |
| `uses nextpas.core.http` | 完整产品面（middleware 全家桶、static/websocket re-export 等） |

公开消费方默认仍可 `uses nextpas.core.http`；生产 checklist 可二选一。

### 1.1 业务域拆分与四件套兑现（Extracted per §1.1；单一 900 行聚合已解耦，主文档瘦身为索引-锚点）

> 单一 CONTRACT 约 900 行已按本节六域兑现四件套拆分；执行时仍守：四件套（base/intf/impl/门面）、L0–L3（L3 http 只依赖 L0–L2）、`bytes.ops` 单源复用、热点 `inline` + 零拷贝视图、资源释放（Close/PoolClear/heaptrc 0 unfreed）不丢；缺能力先反哺 owner（不绕过边界）。子域契约见 `core/docs/http/pool.md` / `retry.md` / `h2defense.md` / `tail.md` / `timeout.md` / `gating.md`（本主文档 §2–§6 仅保留语义摘要与锚点，明细以薄域契约为准，消双重维护）。

| 业务域 | 当前 CONTRACT 锚点 | 抽取后模块（四件套已落地） | Owner / 依赖 | 兑现证据（落地文件 + 约束保持） |
|--------|-------------------|----------------------------|--------------|---------------------------------|
| **Client 连接池** | §5 H1/H2 pool + §2.1 `MaxPoolSize`/`IdleTTL`/`CloseIdle`/`Probe` | `nextpas.core.http.pool`（`pool.base`/`pool.intf`/`pool` 门面，三件套；impl 聚合复用 `impl.h1.pool` + `impl.h2.client.pool` + `CloseIdleConnections`） | L3 http（若跨 http 复用再评估下沉 `net.pool`，当前 L3） | 复用 `bytes.ops` 单源（`CanonicalPoolHostKey` 转发）；热点 `inline`；`PoolClear` 在 destroy/ CloseIdle 全路径；借出/归还 `IdleAtMs` 墙钟淘汰保持；详 `pool.md` |
| **重试 / 退避 / 幂等** | §2.1 `WithRetry` + `HttpIsRetrySafeRequest` + `Retry-After` | `nextpas.core.http.retry`（`retry.base`/`retry.intf`/`retry` 门面；聚合 `client.decorator:TRetryClient` + `client.redirect` + 幂等门闩 + 退避切片） | L3 http | 指数退避切片 ~100ms 可取消；幂等门闩与 pool 同源 `HttpIsRetrySafeRequest`；body 回放 rewind；详 `retry.md` |
| **H2 DoS 防御** | §6 `h2 DoS 防御 stance`（rapid-reset/PING/SETTINGS/CONTINUATION/HPACK/16MB） | `nextpas.core.http.impl.h2.defense`（`defense.base`/`defense.intf`/`defense` 三件套；聚合 `FRapidResetCount`/`FControlFrameFloodCount` + `EscalateHeaderBlockFlood` + `H2_HEADER_LIST_HARD_LIMIT`） | L3 http.impl.h2 | 阈值 `H2_MAX_*=100`/`64KB`/`512`/`64`/`1MB`/`16MB` 冻结；完成-清零不变式；攻击/不误伤双测；详 `h2defense.md` |
| **Keep-Alive Request-Tail** | §3.1 INV-12（request isolation + deferred follow-up） | `nextpas.core.http.impl.h1.framing.tail`（`tail.base`/`tail.intf`/`tail` 三件套；宿主 `impl.h1.conn` 尾巴语义独立化） | L3 http.impl.h1 | 零拷贝 `FPending` 视图（TByteSpan，不复制尾巴）；deferred parse 有序 200→400；handle 前 fail-fast 413/431；详 `tail.md` |
| **超时策略** | §2.1/§2.2 `Timeout`/`ConnectTimeout`/`IdleTTL`/`IdleTimeout`/`ReadTimeout`/`WriteTimeout` 对照 | `nextpas.core.http.timeout`（`timeout.base`/`timeout.intf`/`timeout` 门面，三件套；聚合 `http.base` 单源 `EffectiveConnectTimeout` + `IdleTTL`/`IdleTimeout`/`ReadTimeout` 墙钟判定） | L3 http | 薄转发 `http.base` 单源，不复制阈值；`inline` 墙钟判定 + 零拷贝整数比较；`PoolClear`/`Close` 释放路径不丢；详 `timeout.md` |
| **测试门禁 47 套件** | §6 主门禁 PROJECTS=47 | `core/tests/nextpas.core.http` 已按 theme 部分拆分 `h1/*`/`h2/*`/`client/*`/`middleware/*`/`security/*`（Era3）；余下按阈值再分组见 `gating.md` | 测试域 | `make focused FOCUS=...` 保持；`heaptrc 0 unfreed` 敏感套件；`git diff --check` + `make hygiene`；详 `gating.md` |

*抽取纪律*：1) 行为冻结（focused 双绿）；2) 不复制 `bytes.ops`，复用单源（pool key / tail 视图）；3) 公开面保持 `EHttpError(Kind/Op)` 与 `IHttp*` 稳定；4) 四件套内 `base←intf←impl←门面` 方向（`base←intf←impl←门面`）；5) 跨模块先 `Needs Review`。缺能力先反哺 `errors`/`bytes.ops`/`platform` 等 owner。

---

## 2. 接口契约（核心公开接口，与源码一致）

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
| server 请求解压 | `DecompressMiddleware(AMaxSize)` | 请求 `Content-Encoding: gzip\|deflate` 解压；**默认** `AMaxSize=HTTP_DEFAULT_BODY_READ_MAX`（4 MiB）；`0`=无界（仅测试/工具）；超限/损坏 → **400** `invalid_body`，不进 next |
| client raw body | `HttpReadResponseBodyBytes` / `String` / `StringAuto` | **不**自动解 Content-Encoding（wire 字节） |
| client 显式解码 | `HttpDecodeContentEncoding` / `HttpReadResponseBodyBytesDecoded` / `HttpReadResponseBodyStringDecoded` | 单 coding：`gzip`/`x-gzip`/`deflate`/`identity`/缺省；`AMaxSize>0` 限制解压输出 |
| 不支持编码 | 同上 | `hekProtocol` Op=`content_encoding`（含 multi-coding） |
| 损坏 payload | 同上 | `hekBody` Op=`content_encoding` |
| 非目标 | br / zstd / 浏览器完整 content 栈 / 默认自动 Accept-Encoding 协商 | 不在 C1；未支持编码诚实失败 |

**In-memory request body helpers（Wave SAFE-1）**：

| API | 行为 |
|-----|------|
| `HTTP_DEFAULT_BODY_READ_MAX` | **4 MiB**（与 server `Default.MaxBodySize` 对齐） |
| `HttpReadRequestBodyBytes` / `String` / `Json` | 默认有界；超限 → `EHttpError(hekBody)` Op=`body` |
| `HttpReadRequestBodyBytesMax(AReq, AMax)` | 显式上限；`AMax <= 0` = 无界（**仅**测试/工具） |
| `HttpReadRequestBodyBytesUnlimited` | 命名逃生口 = Max(0)（**仅**测试/工具） |
| `BodyCacheMiddleware` | 默认 max=常量；超限 → **413**，不进入 next |
| `BodyCacheMiddlewareWith(AMax)` | 显式 max；`<=0` 无界（仅测试/工具） |
| `BodyCacheMiddlewareUnlimited` | 命名逃生口 = With(0)（仅测试/工具） |
| `DecompressMiddleware` | 默认解压输出上限=常量；`DecompressMiddleware(0)` 无界（仅测试/工具） |
| `DecompressMiddlewareUnlimited` | 命名逃生口 = (0)（仅测试/工具） |
| Server `MaxBodySize` | **Default=4 MiB**；**`0`=unlimited**（兼容；生产 checklist 禁止无界） |
| `IHttpRequestWithArena` / `HttpRequestArenaOf` | Arena 附着在 request 上（Supports O(1)）；**无**进程全局 map |
| Migration | 需要更大 body/解压时用 Max/With/显式 AMaxSize 放宽；生产禁止依赖无界默认 |

**DeadlineMiddleware（Wave TRUTH-1）**：

| 项 | 行为 |
|----|------|
| 语义 | **非抢占**；仅在 handler **返回后**判定；响应 body **全缓冲** |
| 超时 | 返回后 elapsed ≥ `ATimeoutMs` → **504** `gateway_timeout`（handler 死循环则永不 504） |
| 缓冲上限 | 默认 `HTTP_DEFAULT_BODY_READ_MAX`；`DeadlineMiddlewareWith(ms, max)`；`max<=0` 无界（仅测试）；`DeadlineMiddlewareUnlimitedBuffer` 命名逃生口 |
| 超缓冲 | **413** `payload_too_large`，丢弃缓冲；不 Finalize 成功路径 |
| Headers | `GetHeaders` 透传真实 writer（与 body 缓冲不完全对称） |
| 生产建议 | **默认不装**；硬限时用 server `ReadTimeout`/`WriteTimeout` + cancel；仅短 handler + 小 body 可考虑后验 504 |
| Recovery | 若 `Supports(IHttpResponseWriterCommitState)` 且 `HeadersCommitted` → **不**再写 500；无 CommitState 时 500 失败 → 空 except 有意吞掉 |
| RateLimit | 默认 100 req / 60s；`MaxKeys` 默认 **10000**（满则新 IP **429**，不 LRU）；`MaxKeys=0` 无界键（仅测试） |

**Stream / ResponseTime（Wave TRUTH-2）**：

| API | 行为 |
|-----|------|
| `HttpWriteStream` | 仅从 `IReader` copy 到 writer；**不**设 TE、**不** `WriteHeader`；framing 归 writer |
| `HttpWriteStreamWithLength` | 设 `Content-Length` 后 copy |
| `ResponseTimeMiddleware` | 写 `X-Response-Time`；单元名 `middleware.responsetime`（原 `middleware.timeout` 已改名） |
| 限时对照 | ResponseTime ≠ Deadline（后验）≠ server `ReadTimeout`/`WriteTimeout` |

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
- `WithRetry(N)` — *Extraction candidate: `http.retry`*（聚合重试/退避/幂等，见 §1.1）：对 **429**、**5xx 响应** 与 **`HttpErrorIsRetryable` 异常**
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
  （socketpair / TCP-loopback wake + `platform_socket_poll_or_wake`）；
  仅当 `platform_socket_pair` 失败时退回 probe-only ~10ms `SO_*TIMEO` 切片。
  中途取消抛 `hekCanceled`（经 `ECancelledError` 包装）。
  **Windows（Wave PD-3-3）**：`platform_socket_pair` 用 127.0.0.1 TCP
  loopback 模拟 socketpair；`TNetCancelToken` 拿到 `FHasWake=True`，与 Unix
  同 waitable 路径。probe-only 仅作 pair 失败兜底。
  Linux/macOS/FreeBSD 仍用原生 socketpair（X2）。
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
  - 生产 server：**PD-1B** 起 `THttpServerOptions.Default` 的 Read/Write =
    **30000** ms（与 `Production` 同量级）。长轮询/SSE/需要无界 IO 时显式
    `WithReadTimeout(0)` / `WithWriteTimeout(0)`。产品代码仍推荐命名模板
    **`THttpServerOptions.Production`** 表达意图。IdleTimeout alone 不是完整
    生产模板。示例 `http_hello_server` / `http_websocket_echo_demo` 使用
    Production。
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

**Default vs Production**（PD-1B）：

| 载体 | Default | Production / 生产建议 |
|------|---------|----------------------|
| `THttpClientOptions` | `Timeout=30000`，`ConnectTimeout=0` | 保持 Default 或显式有限 `WithTimeout`；勿依赖 cancel-only |
| `THttpServerOptions` | Read/Write=**30000**（PD-1B）；Idle=30000 | **`Production`** 同 RW 命名模板；长轮询用 `WithReadTimeout(0)`；Idle alone 不足 |
| `TWebSocketOptions` | ConnectTimeout=Timeout=30000 | 同 Default；`=0` 仅显式无界 |

**工厂**：`NewHttpServer(Handler)` → `Default`（现已有限 RW）；`NewHttpServerWithRequestArena`（无 options）→ **Production** + RequestArena。生产 checklist 见 `README.md` § Production checklist。

#### Server IdleTimeout vs client IdleTTL（PD-3-1）— *Extracted: `http.timeout` 薄模块已落地（详 `timeout.md`，本表瘦身为索引-锚点）*

> **业务域拆分（已兑现）**：本对照已抽为 `nextpas.core.http.timeout` 三件套（`timeout.base`/`timeout.intf`/`timeout` 门面，L3，复用 `http.base` 单源 + `timeout.intf` 墙钟 `inline` 判定，零拷贝整数比较，`PoolClear`/`Close` 释放不丢）。**主文档仅保留锚点摘要**，明细与可复用策略见 `timeout.md`；权威语义仍以本 CONTRACT 为准，`timeout.md` 为薄视图转发（不新增阈值源）。

| 旋钮 | 所有者 | 默认 | 薄模块视图 | 0 含义 |
|------|--------|------|-----------|--------|
| **Server `IdleTimeout`** | `THttpServerOptions` | 30000 | `timeout` 策略：请求间隙 gap（`HttpTimeoutShouldCloseServerIdle`） | 不因 idle 主动关（仍受 RW） |
| **Client `IdleTTL`** | `THttpClientOptions` | 90000 | `timeout` 策略：池墙钟淘汰 `HttpTimeoutIsExpired(IdleAtMs,Now,TTL)` | 关闭墙钟淘汰 |
| `ReadTimeout`/`WriteTimeout` | `THttpServerOptions` | 30000 | 同策略：单次 IO 有界（mid-request stall 用 Read） | 无界（长轮询/SSE 显式 0） |
| `Timeout`/`ConnectTimeout` | `THttpClientOptions` | 30000/0 | 同策略：`EffectiveConnectTimeout` 单源转发 | 无界（测试/工具） |

要点（30s vs 90s 差异、PD-1B ReadTimeout 接管 mid-request、生产 checklist）与抽查见 `timeout.md`；原 5 点对照与 M-4 证据保留于该域文档，避免双重维护。

### 2.2.0a Net-dependent capabilities

| Capability | HTTP surface today | Owner | Status |
|------------|-------------------|-------|--------|
| OS `connect()` dial timeout | `ConnectTimeout` / `Timeout` → `TcpConnect(..., ms)` | `nextpas.core.net` + H1/H2 dial | **Landed** (H1/H2) |
| Interruptible blocked socket read on cancel | waitable `NewNetCancelToken` / `NewHttpCancelToken` + poll-or-wake; probe-only only if pair fails | net + H1/H2/WS client wire | **Landed** (X2); **Windows waitable via TCP loopback pair（PD-3-3）** |
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

#### Kind 分类表（正序：按 Kind 字母序，与 `THttpErrorKind` 定义一致）

| Kind | Category | 含义 | 典型 Op / 备注 |
|------|----------|------|----------------|
| `hekArgument` | ecInvalidArgument | 调用方前置条件、配置、消息形状 | 通常无 Op |
| `hekBody` | ecNetwork | body 读写/解码失败 | `redirect` `download` `content_encoding` `transport` |
| `hekCanceled` | ecCancelled | 协作取消 | `cancel` `transport` |
| `hekConnect` | ecNetwork | dial / CONNECT / nil response / 传输连通 | `connect` `round_trip` `transport` `download` `websocket` |
| `hekParse` | ecParse | 方法/URL/响应行等解析失败 | `transport` |
| `hekProtocol` | ecNetwork | HTTP/应用层协议违规 | `transport` `content_encoding` `json` |
| `hekRedirect` | ecNetwork | 重定向策略失败 | `redirect` |
| `hekRegistry` | ecNetwork | transport registry | 通常无 Op |
| `hekStatus` | ecNetwork | ensure-2xx 非 2xx | `ensure` `download`（Status 保留） |
| `hekTimeout` | ecTimeout | 读/写/连接 deadline | `transport` |
| `hekUnknown` | ecNetwork | 仅 `Create(string)` 兼容 | 新代码禁止用 |
| `hekUpgrade` | ecNetwork | WebSocket 升级协商失败 | 通常无 Op |

#### Q3-2 Go-aligned matrix（超时 / 取消 / 413 / 431）

权威证据：`test_http_q3_matrix`（+ 既有 server/security/client 深测）。**不是** Go API 克隆；是语义对齐。

| 场景 | Go `net/http` 参照 | nextPas 契约 | Kind / Op / wire |
|------|-------------------|--------------|------------------|
| Client 整体 deadline | `Client.Timeout` / `context` deadline | `THttpClientOptions.Timeout` / `WithTimeout` | `hekTimeout`；wrap 路径 `Op=transport`；**禁止**裸 `ETimeoutError` |
| Client 协作取消 | `context.WithCancel` → `context.Canceled` | `IHttpCancelToken` + request `.CancelToken` | 检查点 `hekCanceled` + **`Op=cancel`**；传输中途可 `Op=transport` |
| Server body 过大 | `MaxBytesReader` / handler 限流 → 413 | `MaxBodySize` 在 **handler 前** fail-fast | wire `HTTP/1.1 413 Payload Too Large`；**不进** handler |
| Server header 过大 | `Server.MaxHeaderBytes` → 431 | `MaxHeaderSize` 在 parse 期 fail-fast | wire `HTTP/1.1 431 Request Header Fields Too Large`；**不进** handler |

**诚实 residual**

- Go 错误字符串 / `errors.Is` 树 **不** 1:1 复刻；调用方用 `EHttpError.Kind` / `HttpErrorIsTimeout` / `HttpErrorIsUserError`。
- Windows cancel waitable via TCP-loopback `platform_socket_pair`（PD-3-3）；probe-only 仅 pair 失败兜底。Wine smoke：`make -C core/tests/nextpas.core.platform.socket/test_platform_socket_wine wine-runtime-smoke`（含 socket_pair 字节唤醒；**非** real-Windows / **非** Windows scale-ready）。
- Multi-OS HTTP host（R2-5+ / W2-3 / M-1）：`bash core/scripts/http-host-ci-matrix.sh` → `test_http_threaded_host`（钉 `THttpServerOptions.Default.Backend=tsbThreaded`）+ `test_http_iocp_wine`（IOCP wire）+ `test_http_iocp_facade_wine`（产品 facade over IOCP；Windows host 真用例 / 其他 host skip 断言）。**CI hosts**：Linux / macOS / Windows / FreeBSD（`core-ci.yml`）。truth=`host-runtime`；**非** scale-ready / **非** TLS-over-Windows。
- Windows HTTP threaded wine（R2-5）：`make -C core/tests/nextpas.core.http/test_http_threaded_wine wine-runtime-smoke` — 同上 wire 在 Win64+Wine；**非** real-Windows / **非** scale-ready。~~full `uses nextpas.core.http` Win64 交叉 residual（TLS 链触 `system.sysutils` FPC internal）~~ **已消除（M-1，2026-07-26）**：full facade Win64 交叉编译成功，由 `test_http_iocp_facade_wine` 的 uses 常驻钉住防回归；TLS 运行时在 Windows 仍未验证（无 OpenSSL host 环境）。
- Windows IOCP（W2-1..W2-3b landed）：`TCP_SERVER_BACKEND_IOCP` factory 在 Windows 注册；`nextpas.core.net.server.iocp` = AcceptEx + **completion 驱动 recv/send/deadline-wake 数据路径**（零字节 recv readiness 桥 + server 自有 GQCS 循环 + writable waiter timeout 重试 + 有限 `WakeDeadline` 经 `TryCancelByContext` 取消唤醒；生产 H1 session 走完成路径；guard 外仍回退 worker handoff）。**real-Windows host 证据**：`http.iocp_wire` 5 用例 + 0 unfreed（windows-latest，2026-07-26 run 30195741147）；Wine smoke `make -C core/tests/nextpas.core.http/test_http_iocp_wine wine-runtime-smoke`（6 用例；Wine 大 buffer send 整块吞语义差异——backpressure 测试须分块写，真机无此差异）；**产品 facade 端到端（M-1）**：`test_http_iocp_facade_wine` = `THttpServer`（full facade）+ `Backend=tsbIocp` 真 HTTP/1.1 GET + keep-alive 两连发（Wine 3 用例 + 0 unfreed；completion-vs-worker 路径归属仍由 wire suite 证明）；**非** scale-ready。
- 413/431 的深度边角（Expect 后 413、queued follow-up、write-timeout 不串写）见 `test_http_server` / `test_http_security`；Q3-2 矩阵只锁 **主路径语义**。

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

### 3.1 Keep-Alive Request-Tail（INV-12，2026-07-16 定稿）— *Extracted: `http.impl.h1.framing.tail`（四件套已落地，详 `tail.md`）*

> **业务域拆分（已兑现）**：本节尾巴域已抽为 `nextpas.core.http.impl.h1.framing.tail` 四件套（`tail.base`/`tail.intf`/`tail` 门面；实现聚合 `impl.h1.conn.FPending` 语义，L3，依赖 `bytes.ops` 单源 + `impl.h1.parser`）。触发条件见 §1.1；抽取保持：零拷贝 `FPending` 视图（TByteSpan，不复制尾巴）、deferred follow-up 有序、资源 `Close` 不丢。

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
  公开前置条件见下表。

### 4.1 SSE production contract（Wave Q1-1）

`StartSSE` / `ISSEEventWriter` 是 **H1 写端 helper**，不是 EventSource 客户端、
不是消息总线、不是 WebSocket 替代。

| 阶段 | 行为 |
|------|------|
| **StartSSE(AW)** | nil AW → `hekArgument` Op=`sse`。设置 `Content-Type: text/event-stream`、`Cache-Control: no-cache`、`Connection: keep-alive`，`WriteHeader(200)`，返回 open writer。 |
| **WriteEvent / WriteEventSimple** | 编码 `retry:` / `event:` / `id:` / 多行 `data:` + 空行结束；然后 **Flush**。 |
| **WriteComment** | `:` 注释行（可心跳）；Flush。 |
| **WriteRetry** | 单独 `retry:` 行；Flush。负值 → `hekArgument` Op=`sse`。 |
| **Close** | **幂等**；仅本地 `IsOpen=false`，不关闭底层 TCP。 |
| **IsOpen** | Start 后 true，Close 后 false。 |

| 错误 | Kind | Op |
|------|------|-----|
| nil writer / 字段注入（event/id 含 CR/LF）/ id 含 NUL / retry&lt;0 | `hekArgument` | `sse` |
| write-after-close | `hekProtocol` | `sse` |
| zero-progress write / over-report / underlying write or flush failure | `hekProtocol` | `sse` |

**限制（诚实）**

- 仅写端；无自动重连客户端 / Last-Event-ID 消费 API。
- 无界背压由底层 `IHttpResponseWriter` 与 server `WriteTimeout` 决定。
- 长连接 handler 会占用 server 执行路径；在 epoll **reactor-inline**（S1-1 默认）下，阻塞 handler 会拖累同 reactor 其他连接——长推送宜短事件或后续 offload。
- 非 H2/H3 SSE；非 room/bus。

证据：`test_http_middlewares` SSE 套件 + `test_http_server` `Live SSE event stream`。

### 4.2 Multipart bounded stream ingest（Wave Q1-2）

字符串 API `ParseMultipartFormData` / `EncodeMultipartFormData` **保留不变**。
新增 **有界流式摄入**（非磁盘 spool、非第二套 body 家族）：

| API | 行为 |
|-----|------|
| `MultipartParseOptionsDefault` | `MaxBytes = HTTP_DEFAULT_MULTIPART_MAX_BYTES`（4 MiB，与 server Default.MaxBodySize 对齐量级） |
| `ParseMultipartFormDataFromReader(Reader, Boundary, Options)` | 从 `IReader` 读至多 `MaxBytes` 字节，再解析 multipart |

| Ownership | 规则 |
|-----------|------|
| `IReader` body | **调用方拥有**；parse **不** Close reader |
| `TMultipartFormData` | 值类型；Fields/Files 内容由调用方持有 |
| 超限 / 失败 | 抛 `EHttpError`；已分配缓冲随异常释放 |

| 错误 | Kind | Op |
|------|------|-----|
| nil reader / empty boundary / MaxBytes≤0 | `hekArgument` | `multipart` |
| body 超过 MaxBytes | `hekBody` | `multipart` |
| 读路径其它失败 | `hekProtocol`（包装） | `multipart` |

**诚实限制**：解析结果仍将 part 内容放入 `string` / `THttpFile.Content`（与既有模型一致）；**不是**零拷贝磁盘 spool。`PostMultipart` / `EncodeMultipartFormData` 仍为内存编码。大上传请显式设 `MaxBytes` 并在 handler 侧配合 server `MaxBodySize`。

证据：`test_http_form` FromReader 套件。

### 4.3 Observability 最小 seam（Wave Q1-3）

`MetricsMiddleware` / `MetricsMiddlewareWith` / `MetricsMiddlewareWithFields` +
`IHttpMetricsCollector` 是 **opt-in** 可观测 seam。

| 规则 | 行为 |
|------|------|
| 默认开销 | **零**：不安装 middleware 则无采集、无锁、无回调 |
| Collector | `NewHttpMetricsCollector` + `Snapshot` / `Reset`；线程安全 |
| 字段 | `TotalRequests`、2xx–5xx 类计数、`TotalDurationUs`、`RequestBytes`、`ResponseBytes` |
| 计时 | handler 前后 `try/finally`；**异常仍记录** |
| 未提交 status | handler 抛异常且 `GetStatus=0` → 记 **status=500**（计入 5xx） |
| Callback | `With` / `WithFields` 推送外部系统；**callback 内异常被吞掉**，不破坏请求 |
| 构造失败 | nil collector/callback → `hekArgument` Op=`metrics` |

**非目标**：OpenTelemetry / Prometheus exporter / 全局强制 metrics / 分布式 tracing。

证据：`test_http_middlewares` Metrics 套件（含 exception + callback isolation）。

### 4.4 H1 长连接写失败 / backpressure（Wave Q1-4）

H1 server 响应写路径（threaded whole-run 与 epoll **poll-owned drain**）对长连接
背压与写失败的 **final 契约**。实现与 focused 证据已长期存在；本节约成可读表。

| 主题 | 语义 | 证据（`test_http_server`） |
|------|------|---------------------------|
| **WriteTimeout = 0** | 无写 deadline（`THttpServerOptions.Default` 测试兼容） | Server options Default vs Production |
| **WriteTimeout > 0** | budget 从 **socket 真实 drain 开始**，**不**含 handler 在内存中拼响应的时间 | Real socket write timeout ignores slow buffered handler（threaded + epoll） |
| **Would-block** | poll 路径订 `peWritable` 继续 drain；**仅有实际写出进度时** re-arm write deadline | poll-driven drains response via writable events；partial timed drain |
| **Write deadline 到期** | 安全关闭连接；`WakeDeadline → infinite`；**不**追加 500；**不**再消费 follow-up pipeline | times out stalled drain on deadline wake；partial timed drain stops buffered follow-up |
| **Zero-progress write** | 首次写失败/零进度 → **立即停 session**；不消费后续 pipelined 请求 | Session stops after zero-progress response write failure |
| **已提交响应后 handler 异常** | **不**再向 wire 追加 synthetic 500 | Committed response exception 相关用例 |
| **有界 response queue** | untimed poll：active drain + **1** queued；follow-up 错误保序 | queues bounded responses / queues follow-up 400/413/… |
| **Timed stall + pipeline** | `WriteTimeout>0` 且 drain 已 stall 时，**不**继续处理同连接后续请求 | Real socket write timeout backpressure stops pipeline（threaded + epoll）及「does not emit follow-up 4xx/501」系列 |
| **Direct error 响应** | parser/size/Expect 等 fail-fast 错误响应同样 arm write timeout | Direct error response arms write timeout on … |
| **S1-1 关系** | `PreferPollWorkerHandoff=False`（默认）只决定 **handler 在 reactor 还是 worker 执行**；**不改变** drain/backpressure/WriteTimeout 语义 | S1-1 + 本表 drain 测 |

**生产建议**：使用 `THttpServerOptions.Production` 或 Default（PD-1B 后 RW 同为 30s）；长写流式仍设有限 `WithWriteTimeout`；勿把 IdleTimeout alone 当完整模板。

**非目标**：严格 wall-clock SLA 冻结为 CI 阈值；跨机 backpressure 排行榜；改 WriteTimeout 默认值。

证据索引（非穷尽）：`Session stops after zero-progress…`、`H1 poll-driven session times out stalled drain…`、`Real socket write timeout backpressure…`（threaded/epoll）、`Write timeout before any wire bytes…` / `after partial wire bytes…`、source-contract `H1 write/backpressure contract`。

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
| 池 / 多路表征 | 默认 `IHttpTransport.RoundTrip`：单连接**串行**一流；池按 authority/`MaxPoolSize` 复用。**Era 8 I3**：可选 `IHttpTransportMultiplex.RoundTripMany` 同连接并发多流（H2 only） | pool tests；`RoundTripMany` focused |
| Server push | `ENABLE_PUSH=0`；`PUSH_PROMISE` → GOAWAY `PROTOCOL_ERROR` | client SETTINGS + PUSH tests |
| TLS H2 | ALPN `h2`；`http://` prior knowledge；无 h2c Upgrade | facade + **`test_http_h2_tls_alpn` (H2P-3)** |

**诚实 residual（非缺口伪装）**：

- 默认 `IHttpClient.Send` / `IHttpTransport.RoundTrip` 仍为串行一流。同连接多路走 **`IHttpTransportMultiplex.RoundTripMany`**（`Supports` 探测；H2 实现，H1 无此接口）。
- `RoundTripMany`：同 authority（scheme/host/port）；响应按请求下标排序；受 peer `MaxConcurrentStreams` 约束；流 ID 客户端奇数递增；GOAWAY 期间未完成且 stream id > last-stream-id → `hekProtocol`；cancel 与单次 RoundTrip 同源（首请求 token）。
- OpenSSL backend heaptrc：能力缓存值语义重置，test_http_client heaptrc 0 unfreed。
- **Q3-3 / RH-1 / C-A H1 HTTPS**：
  - **Client H1 direct HTTPS**（`TLSContext` + `https://`）：生产路径；smoke
    见 `test_http_https_smoke`（吞吐 + p50/p99；heaptrc **0 unfreed**）。
  - **RH-1 连接复用**：根因 = `TTlsTcpStream` 未实现 `ITcpStreamRuntime` →
    `PooledConnectionIsReusable` 恒 false → 每请求 re-dial。已补 runtime 委托
    到 inner TCP；smoke 锁 `server_accepts=1` 且 N keep-alive GET。
  - **Server `THttpServerOptions.TLSContext`**：**产品路径**按版本 wrap：
    - **H1**（默认 / `hvHttp10`/`hvHttp11`）：`NewH1TlsServerTransport` →
      TLS accept + ALPN `http/1.1`（空 ALPN 兼容）→ 内层 H1 serve
      （`test_http_h1_tls_server`）。
    - **H2**：`NewH2TlsServerTransport` → ALPN `h2` 强制
      （`test_http_h2_tls_alpn`）。
  - Q3-3 smoke origin 仍可用最小 `NewTlsServerTcpStream` 字节源做 client
    latency 测；产品 server 入口是 `NewHttpServer` + `TLSContext`。
  - **仍不**宣称 HTTPS scale-ready；scale KPI 仍是 **plain H1 epoll**。
- Cancel 平台路径（**Wave PD-3-3**）：Unix 原生 socketpair+poll；Windows
  TCP loopback pair + 同一 waitable 路径。probe-only 仅 pair 失败兜底。
  见 §2.2.0 / §2.2.0a。
- H3 / QUIC：无产品需求 + Blocked on QUIC；禁止空 facade。h2c Upgrade、CONNECT/WS-over-H2：Park（见 ROADMAP）。

#### Client connection pool（Wave A2）— *Extracted: `http.pool` 四件套已落地（聚合 H1/H2 池，见 §1.1 + `pool.md`）*

| 语义 | 行为 | 证据 |
|------|------|------|
| Pool key / authority | H1：canonical host + port（`https\|` / `connect\|` / proxy+target 变体编码进 key）；H2：host + port + secure | H1/H2 pool reuse tests |
| `MaxPoolSize` | **每 authority 最大空闲连接数**（默认 64）；**不是**跨 host 全局上限 | `test_http_client` / `test_http_h2_client` per-authority |
| Idle put | 仅 keep-alive / `IsReusable` 连接入池；超 per-authority 上限则关闭新归还连接 | pool max / non-reusable tests |
| Idle clear | `IHttpClient.CloseIdleConnections` → transport `IHttpTransportIdleConnections.CloseIdleConnections` 清空全部 authority 的空闲项；destroy 亦 `PoolClear` | CloseIdle + destroy source-contract |
| `IdleTTL` | 墙钟空闲淘汰（默认 **90000** ms）；`WithIdleTTL` 外层胜；**0** = 关闭墙钟淘汰；负值 `hekArgument`；借出/归还路径淘汰过期项（`IdleAtMs` 在 put 时打戳） | `test_http_client` IdleTTL expires / IdleTTL=0 keep；H1/H2 同源实现 |
| 主动健康探测（Wave I1） | **借出路径**（`PoolGet`，锁外）：H1 非阻塞 `TryRead` 探针（WouldBlock=活；数据/EOF/错误=丢弃）；H2 在读缓冲空时发 PING，等 ACK（`PingTimeout` 默认 5000ms；**0**=关闭 PING 探针，仅状态位）；失败连接 Close 后继续取池或 dial | `test_http_client` H1 probe source-contract；`test_http_h2_client` PING on borrow / discard closed / PingTimeout=0 |
| 并发模型 | 默认同步 `RoundTrip` 串行一流；同 transport 可多线程各自 RoundTrip（池 mutex）；**I3** 同连接多路 = `IHttpTransportMultiplex.RoundTripMany`（不改默认 Send 语义） | I3 focused + A1 residual |

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

## 6. 测试门禁 — *Extracted awareness: 47 suites 已按 theme 部分拆分，余下按 §1.1 + `gating.md` 再分组已落地*

主门禁：`core/tests/nextpas.core.http/Makefile`（**47** suites）

纳入：base/url/headers/message/form/cookie/router/middleware(s)/hsts/static/
client/contract/registry/h1*/server/security/stress/h2*/websocket*/fuzz/https_redirect

旁路：benchmarks、examples、smoke、integration、tls_real（环境/性能/长集成）

> **业务域拆分（已兑现）**：47 套件已从单体 `client/server` 拆出 `client_redirect`/`client_body_helpers`/`server_expect`/`server_chunk`（Era3）；门禁分组契约已抽至 `gating.md`（`h1/*`/`h2/*`/`client/*`/`middleware/*`/`security/*` 机械分组，阈值单 lpr >10k）。分组保持 `make focused FOCUS=...` + `heaptrc 0 unfreed` + `git diff --check` + `make hygiene`。

#### h2 DoS 防御 stance — *Extracted: `http.impl.h2.defense` 四件套已落地（聚合本表计数器+阈值+Escalate，见 §1.1 + `h2defense.md`）*

| 攻击向量 | 防御机制 | 阈值 | 清零条件 | 测试对 |
|----------|---------|------|---------|-------|
| CVE-2023-44487 rapid-reset（HEADERS+RST 循环） | `FRapidResetCount` 计数 → GOAWAY(ENHANCE_YOUR_CALM) | `H2_MAX_RAPID_RESETS = 100` | 任意请求成功完成（`MarkRequestHandled`） | 攻击测试 + 不误伤（198 resets 中间穿插1完成） |
| CVE-2019-9512 PING flood | `FControlFrameFloodCount` 计数 → GOAWAY(ENHANCE_YOUR_CALM) | `H2_MAX_CONTROL_FRAME_FLOOD = 100` per batch | 任意请求成功完成 | 攻击测试 + 不误伤（198 PINGs 中间穿插1完成） |
| CVE-2019-9515 SETTINGS flood | 同上计数器（共用 `FControlFrameFloodCount`） | 同上 | 同上 | 同框架覆盖 |
| CVE-2024-27316 CONTINUATION flood（HEADERS 后无尽 CONTINUATION） | stream 层三重边界超限 → reset code=ENHANCE_YOUR_CALM，session `EscalateHeaderBlockFlood` 升级为 GOAWAY(ENHANCE_YOUR_CALM) + 关闭 + 清 `FPendingContinuationStreamID` | `H2_MAX_HEADER_BLOCK_BYTES=64KB` / `H2_MAX_HEADER_FRAGMENTS=512` / `H2_MAX_EMPTY_FRAGMENTS=64` | — （单次连接级致命） | 攻击测试（70 空 CONTINUATION）+ 不误伤（合法 3 分片 CONTINUATION 完成 handler） |
| HPACK 放大炸弹（RFC 7541 §10.5：小压缩块经索引引用解码成巨型 header list） | `FinalizeHeaders` 无条件累计解码 header-list size（§4.1 name+value+32），超 `H2_HEADER_LIST_HARD_LIMIT` → `h2hfrHeaderListTooLarge` → 431（与广播的软 `MAX_HEADER_LIST_SIZE`=0 无关，硬 backstop 独立于软 setting） | `H2_HEADER_LIST_HARD_LIMIT = 1MB`（软限若>0则取 min） | — （请求级 431） | 攻击测试（~4KB 压缩 → ~1.26MB 解码 320 索引引用）+ 不误伤（普通请求 h2hfrOk），no-harm 经过度激进 mutation(=100) 验证 |
| 内存 exhaustion（巨型帧） | `H2_WIRE_READ_HARD_LIMIT = 16MB` → GOAWAY(ENHANCE_YOUR_CALM) | 16 MB | — | 既有测试 |

> **不变式**：`H2_MAX_HEADER_BLOCK_BYTES=64KB` 对*压缩*字节封顶，合法请求几乎不靠压缩红利、解码后 ≈ 压缩大小 ≤ 64KB，远在 1MB 硬上限之下；因此硬 backstop *只可能*在放大攻击时触发，永不误伤合法流量。

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
| 2026-07-24 | 3.23 | Wave PD-3-3：Windows `platform_socket_pair` TCP loopback → waitable cancel |
| 2026-03-14 | 3.24 | Wave SAFE-1：`HTTP_DEFAULT_BODY_READ_MAX`；`HttpReadRequestBodyBytes*` 默认有界；`BodyCacheMiddlewareWith`；超限 hekBody/413 |
| 2026-03-14 | 3.25 | Wave SAFE-2：`DecompressMiddleware` 默认 `AMaxSize=HTTP_DEFAULT_BODY_READ_MAX`；`0` 仅显式无界；超限仍 400 |
| 2026-03-14 | 3.26 | Wave SAFE-3：`IHttpRequestWithArena` 请求附着；删除 `GArenaMap`；`test_http_mem` 入主 PROJECTS |
| 2026-03-14 | 3.27 | Wave TRUTH-1：`DeadlineMiddleware` 默认缓冲 4 MiB；`DeadlineMiddlewareWith`；超缓冲 413；非抢占语义入 CONTRACT |
| 2026-03-14 | 3.28 | Wave TRUTH-2：`HttpWriteStream` 注释对齐实现；`middleware.timeout`→`responsetime`；inventory 对齐 |
| 2026-03-14 | 3.29 | Wave STRUCT-1/3：`impl.h1.pool` 抽出；`test_http_stream`/`test_http_sse` 入主 PROJECTS=43 |
| 2026-03-14 | 3.30 | Wave STRUCT-2：`client.redirect` + `client.decorator` 机械抽出；redirect/retry 语义冻结 |
| 2026-03-14 | 3.31 | Era0：inventory **64** 单元；HTTP 生产/测试禁止 `uses` FPC RTL（`test_http_contract` source-contract）；6 suite 去掉 `SysUtils` |
| 2026-03-14 | 3.32 | Era R2-2 STRUCT-opt：`impl.h2.client.pool` + `client.helpers` + `impl.h1.wire`；inventory **67**；decorator 无 `uses client` |
| 2026-03-14 | 3.33 | Era R2-3 test split：`test_http_client_redirect` / `body_helpers` / `server_expect` / `server_chunk` 入主 PROJECTS=**47**；client/server lpr 各 <10k |
| 2026-03-14 | 3.34 | Era R2-4：`http.fuzz` → tests support；BodyCache GetBody 共享 TBytes 只读视图；inventory **66** |
| 2026-03-14 | 3.35 | Era R2-5：Wine WIN-0..2；`test_http_threaded_wine`；WIN-3 IOCP Parked；H3 Blocked；Windows scale=No |
| 2026-03-14 | 3.36 | Era R2-5+：`test_http_threaded_host` + `http-host-ci-matrix.sh` 挂 Linux/macOS/Windows/FreeBSD CI；Wine 仍 smoke-only；scale=No |
| 2026-03-14 | 3.37 | STRUCT residual：`impl.h1.client`（TH1ClientTransport）+ `impl.h1.prepend`（TReadPrependTcpStream）；`impl.h1` 保留 server + re-export；inventory **68** |
| 2026-03-14 | 3.38 | STRUCT residual：`TH1FastRequestSnapshot` / body reader → `impl.h1.fast`；`NewH1FastRequestSnapshot`；server 仅保留 gate + factory 调用 |
| 2026-07-25 | 3.39 | h1.poll/serve hard-cut：`impl.h1.conn` + `impl.h1.serve`（`H1ServeRun`）+ `impl.h1.poll`（`H1PollAdvance*`）；`impl.h1` 门面；inventory **71** |
| 2026-07-26 | 3.40 | residual do-all：`http.minimal`；`impl.h2.client.body`；H1 except 卫生；tooling mem/`lane_gate`；inventory **73** |
| 2026-07-26 | 3.41 | h2.session 机械抽：`impl.h2.streammap` + `impl.h2.session.preface` + `impl.h2.session.writer`；session ~1582；inventory **76** |
| 2026-07-26 | 3.42 | h2.session 纯 helper 抽出：`impl.h2.session.helpers`；session ~1536；inventory **77** |
| 2026-07-26 | 3.43 | h2.client 纯 helper 抽出：`impl.h2.client.helpers`；client ~2022；inventory **78** |
| 2026-07-26 | 3.44 | 共享 cancel 桥接：`impl.cancel.adapter`（`THttpNetCancelAdapter` + `ApplyHttpCancelToken`）；h1/h2/websocket 去重；inventory **79** |
| 2026-07-26 | 3.45 | h2 settings 共享：`H2ParseSettingsPayload` + `H2MinUInt32` → `impl.h2.types`；client/session 去重 |
| 2026-07-26 | 3.46 | h2 巨石机械拆：`impl.h2.wire` + `impl.h2.client.streams` + `impl.h2.session.request`；client ~1759 / session ~1411；inventory **82** |
| 2026-07-26 | 3.47 | Era W2（W2-1..W2-3b）：IOCP completion 驱动 recv/send/deadline-wake；host matrix 增 `http.iocp_wire`（真 Windows 证据 run 30195741147）；residual 措辞对齐；scale=No 维持 |
| 2026-07-26 | 3.48 | M-1 产品 facade over IOCP：`test_http_iocp_facade_wine`（THttpServer+tsbIocp GET/keep-alive，Wine 3 用例）；full facade Win64 交叉 residual 消除（uses 常驻钉住）；host matrix 增 `http.iocp_facade` |
| 2026-07-26 | 3.49 | Era P DoS defense：`FRapidResetCount` + `FControlFrameFloodCount` → GOAWAY(ENHANCE_YOUR_CALM)；`H2_MAX_RAPID_RESETS=100`/`H2_MAX_CONTROL_FRAME_FLOOD=100`；request-completion 清零；`test_http_h2_session` 4 passed + 4 RED→GREEN；`CONTRACT.md` DoS stance 表 + §6 suites 计数修正 35→47 |
| 2026-07-26 | 3.50 | Era P-4 CONTINUATION flood（CVE-2024-27316）连接级升级：`EscalateHeaderBlockFlood` 把 stream 层 ENHANCE_YOUR_CALM reset 升级为 GOAWAY + 关闭 + 清 `FPendingContinuationStreamID`（原缺口：只 RST 单流留连接 1:1 放大挂起）；HandleHeaders/HandleContinuation 两处 reset 分支共用；`test_http_h2_session` 43 passed（+2：攻击 70 空 CONTINUATION，no-harm 合法 3 分片；均 RED→GREEN，no-harm 经过度激进 mutation 验证） |
| 2026-07-26 | 3.51 | Era P-5 HPACK 放大炸弹（RFC 7541 §10.5）硬 backstop：`FinalizeHeaders` 的 header-list-size 守卫原被 `if FMaxHeaderListSize > 0` 门控，而默认 `MAX_HEADER_LIST_SIZE=0`（RFC「不广播显式上限」的有意姿态）→ 守卫关闭 → ~4KB 压缩块经索引引用解码成 ~1.26MB 无界物化。新增 `H2_HEADER_LIST_HARD_LIMIT=1MB` 绝对上限（与 `H2_WIRE_READ_HARD_LIMIT=16MB` 同型，独立于软 setting）：累计移出软门控、无条件强制，超限 → `h2hfrHeaderListTooLarge` → 431（复用既有 431 通道，软限若>0仍取 min）。`test_http_h2_stream` 39 passed（+2：攻击 320 索引引用 ~1.26MB，no-harm 普通请求；均 RED→GREEN，no-harm 经过度激进 mutation(=100) 验证）；h2 全家回归全绿（session 43 含 431 soft 路径不变） |
| 2026-07-18 | 3.19 | Wave R4：HTTPS 1×41B 清零 — capabilities cache `Default` 替代 `FillChar` |
| 2026-07-20 | 3.20 | Q3-2：timeout/cancel/413/431 Go 语义矩阵（§ Kind 表下 + `test_http_q3_matrix`） |
| 2026-07-20 | 3.21 | Q3-3：H1 HTTPS smoke 吞吐/延迟 + residual（pool 复用未证；registry H1 server TLS residual） |
| 2026-07-20 | 3.22 | RH-1：TLS stream `ITcpStreamRuntime` → HTTPS pool keep-alive reuse |
| 2026-08-31 | 3.52 | 时效修复：文件数 82→92 校正（`ls core/src/nextpas.core.http*.pas`），taxonomy 按 Kind 字母正序 |
| 2026-09-02 | 3.53 | 拆分优雅度：单一 900 行 CONTRACT 跨池/重试/DoS/Keep-Alive/门禁多域未标注 extraction 缺口修复 — 新增 §1.1 业务域拆分与可抽新模块候选表（池/重试/DoS/TAIL/门禁 47，含 owner/L0-L3/四件套/bytes.ops单源/inline零拷贝/资源释放约束）+ §3.1 Tail 与 §6 门禁/DoS 行级 extraction 标注；版本 3.52→3.53 |
| 2026-09-03 | 3.54 | 拆分优雅度兑现：§1.1 五域四件套落地 — `pool`/`retry`/`impl.h2.defense`/`impl.h1.framing.tail` 新增 base/intf/门面三件套 + 聚合实现（bytes.ops 单源复用、热点 inline、零拷贝 TByteSpan、`PoolClear`/`Close` 释放不丢），门禁再分组抽至 `gating.md`；CONTRACT 900 行聚合解耦为域契约 `pool.md`/`retry.md`/`h2defense.md`/`tail.md`/`gating.md`，§3.1/§6 行级标注 candidate→extracted；版本 3.53→3.54 |
| 2026-09-04 | 3.55 | 拆分优雅度瘦身 + 超时薄模块：§1.1 六域四件套（新增 `timeout` 薄模块 `timeout.base/intf/pas` 三件套，复用 `http.base` 单源、`inline` 墙钟判定、零拷贝整数比较、`PoolClear`/`Close` 释放不丢）；CONTRACT 主文档瘦身为索引-锚点（§2–§6 仅保留摘要 + 指向 `pool.md`/`retry.md`/`h2defense.md`/`tail.md`/`timeout.md`/`gating.md`，消双重维护）；`§282 IdleTimeout/IdleTTL/ReadTimeout` 对照抽为可复用 `timeout.md`；库存 98→101；版本 3.54→3.55 |
