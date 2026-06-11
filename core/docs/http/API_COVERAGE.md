# nextpas.core.http API Coverage Matrix

最近更新：2026-06-12

这份矩阵只记录公开 API 的覆盖状态，不替代测试输出。状态含义：

- **focused**：有直接面向该公开契约的测试。
- **integration**：通过端到端路径覆盖，但还缺少更窄的契约测试。
- **indirect**：被其他 API 或场景带到，不能单独证明契约。
- **gap**：公开面存在，但还没有足够测试证据。

## 当前结论

- 2026-06-06 API 对标结论：
  - 已够稳：`IHttpServer.ListenAndServe` / `Shutdown` / `LocalAddr` / `IsRunning`
    的生命周期形状足够清晰，保持同步 facade，不把 Go `net/http` 或 Rust
    async runtime 细节泄漏到 public contract；handler / middleware / router
    组合也已符合小接口、可组合、可测试的稳定面。
  - 已够稳：static serving 与 WebSocket 仍停在 helper/facade 层更合适。当前
    helper 已有 focused coverage；没有 range、streaming static file、WebSocket
    extension negotiation 等稳定 contract 前，不扩大成独立 builder 或 service
    family。
  - 已够稳：H2/H3 public surface 仍只保留 registry / transport seam 和规划文档。
    当前 H2 只有内部 HPACK Huffman codec foundation 和 focused proof；不创建伪
    H2/H3 public API，不用空实现制造“支持”假象。
  - 继续补齐：landed internal registry 现在也有 future-version positive proof。
    `test_http_registry` 直接锁住“调用方可注册 custom `hvHttp2` client transport /
    custom `hvHttp3` server transport，并把它们设为 default version 供 concrete
    constructor 消费”的 seam contract；`test_http_contract` 又进一步锁住
    `nextpas.core.http.NewHttpClient(Options)` / `NewHttpServer(Handler, Options)`
    这两条 facade consumer path 也会吃到同一套 future default 解析。以上都只证明
    registry readiness，不声明任何内建 H2/H3 protocol implementation 已存在。
  - 已补齐：client 侧核心 custom request construction gap 已实质收口。当前
    `NewRequest` public surface 已覆盖 `TUrl` / URL string、headers-only、
    nil-literal compatibility shim、`IReader + ContentLength`、Pascal `string`
    body、`TBytes` body、显式 `Content-Type` body helper、以及“不先手造 headers”
    的 convenience overload；调用方不必再直接构造 concrete `THttpRequest`，
    就能清晰表达 method、headers、body 与 body length / ownership 形状。
  - 暂不做：完整 fluent `IHttpRequestBuilder`、per-request timeout / redirect
    override、form/json helper family、streaming/chunked request body ownership、
    response charset decoding / sniffing 等扩展仍属于刻意未认领范围；这些能力
    只有在 contract 足够清晰、能稳定公开时才继续扩面。
  - 本轮补齐：新增 `NewRequest(Method, Url, Headers, Body, ContentLength)` public
    helper，经 `nextpas.core.http` facade 转发。nil headers 会创建空 header set；
    body/positive length 会写入 `content-length`；negative content length 会抛
    `EArgumentError`。caller-supplied `content-length` 现在必须是单个 numeric
    value 且匹配 helper body length；duplicate、invalid、overflowing 或
    conflicting value 都会 fail-fast。caller-supplied `transfer-encoding` 当前也
    直接拒绝，避免在尚无 streaming/chunked request body ownership API 时构造 H1
    writer 无法合法发送的请求。传入的 headers 视为 request-owned，helper 可能写入
    `content-length`，调用方不应把同一 headers 对象复用到不同 request shape。
    `test_http_message`、`test_http_contract` 和 `test_http_client` 分别锁住
    helper contract、facade 可见性和 `IHttpClient.Send` live header/body 发送路径。
  - 本轮补齐：新增 `NewRequest(Method, Url, Headers)` public helper。它只表达
    method/url/custom headers，保持 nil body、`ContentLength = 0` 且不自动写入
    `content-length`；调用方不必再为常见 headers-only request 手写
    `Headers, nil, 0`。`test_http_message`、`test_http_contract` 和
    `test_http_client` 分别锁住 helper contract、facade 可见性，以及 live
    round-trip header/path/query 语义与“不自动发布 `content-length` header”这一条
    client/server contract；显式单个 numeric `content-length: 0` 可保留，positive /
    invalid / duplicate `content-length` 与任何 `transfer-encoding` 都会被拒绝。
  - 同步收紧：为避免新增 `Headers` overload 破坏旧的 `NewRequest(Method, Url, nil)`
    源兼容性，public surface 保留了 nil-literal compatibility shim。`nil` 第三参
    仍解析成历史 empty-`TBytes` helper 语义，也就是 zero-length body +
    `content-length: 0`，不会静默落到新的 headers-only contract。对应
    compile/runtime proof 已加到 `test_http_message` 和 `test_http_contract`。
  - 继续补齐：`NewRequest(Method, Url)` 与
    `NewRequest(Method, Url, Headers, Body, ContentLength)` 现在都接受 URL string
    overload。调用方可以直接用 `NewRequest(hmPost, 'http://...')` 构造
    `IHttpClient.Send` 请求，不必先手写 `TUrl.Parse`；解析、nil headers、
    `content-length` 与 negative length 语义沿用同一 helper contract。
  - 继续补齐：新增 `NewRequest(Method, Url, Headers, BodyText)` public helper。
    调用方可以用 Pascal string 构造 request body；helper 会复制 string 到
    in-memory reader 并发布 `Content-Length`，但不自动设置 `Content-Type`。
    `test_http_message`、`test_http_contract` 与 `test_http_client` 分别锁住
    helper contract、facade 可见性和 live `IHttpClient.Send` 发送路径。
  - 继续补齐：新增 `NewRequest(Method, Url, Headers, BodyBytes)` public helper。
    调用方可以用 `TBytes` 构造 binary request body；helper 会复制 bytes 到
    in-memory reader 并发布 `Content-Length`，但同样不自动设置 `Content-Type`。
    `test_http_message` 锁住 `TUrl` 与 URL string overload，`test_http_contract`
    锁住 facade 可见性，`test_http_client` 锁住 live `IHttpClient.Send` 发送零字节
    与高字节 payload 的路径。这补齐 Go/Rust 常见 binary body ergonomics，但仍不
    引入完整 request builder 或 streaming/chunked request body ownership API。
  - 继续补齐：`NewRequest(Method, Url, Body, ContentLength)`、
    `NewRequest(Method, Url, BodyText)` 与 `NewRequest(Method, Url, BodyBytes)`
    现在也直接支持“不先手造 headers”的 public overload。它们复用现有
    `Headers=nil` contract：自动创建空 header set，只发布 `Content-Length`，
    但不猜测 `Content-Type`。`test_http_message`、`test_http_contract` 与
    `test_http_client` 分别锁住 helper contract、facade 可见性和 live
    `IHttpClient.Send` 发送路径。这样调用方可以像 Go `NewRequest(...)` /
    Rust 常见 request body helper 那样先表达 method/url/body，再按需决定是否
    追加 custom headers，而不必为了“无自定义头”也先分配一个 header 容器。
  - 继续补齐：新增 `NewRequest(Method, Url, ContentType, BodyText)`、
    `NewRequest(Method, Url, ContentType, BodyBytes)` 与
    `NewRequest(Method, Url, ContentType, Body, ContentLength)` public helper。
    这组 overload 解决了“调用方只想声明 request body 的 `Content-Type`，却仍得先
    手造一个 headers 容器”的剩余 ergonomics 缺口。helper 只发布调用方显式提供的
    `content-type` 与既有 `content-length`，不再额外猜测其他 header，也不上完整
    builder family。`test_http_message`、`test_http_contract` 与
    `test_http_client` 分别锁住 helper contract、facade 可见性和 live
    `IHttpClient.Send` 发送路径。
  - 继续收紧：`IHttpClient.Post` / `Put` / `Patch` shortcut 现在共享内部
    bytes-buffer request helper。它们仍会读取 `IReader` 以发布 `Content-Length`，
    但不再先 materialize 到 Pascal string 再转回 bytes；`test_http_client` 用
    source-contract 锁住 single helper 与 no-string-buffer 实现形状，并继续保留
    live POST / PUT / PATCH 行为覆盖。
  - 本轮补齐：`IHttpClient.Post` / `Put` / `Patch` 现在也直接接受 Pascal
    `string` 与 `TBytes` body overload。三种 shortcut body 形状都会发布
    `Content-Length`，并转发调用方显式提供的非空 `Content-Type`；空
    content type 会省略该 header 而不是发送空 header value。`string` /
    `TBytes` overload 复用现有 `NewRequest(..., BodyText)` /
    `NewRequest(..., BodyBytes)` contract，而不是再扩一层新的 free-function
    facade。`test_http_client` 锁住 live string / bytes body wire 语义，
    `test_http_contract` 锁住 facade surface 可见性。
  - 继续补齐：新增 `HttpReadResponseBodyString(Resp)` public helper。它直接消费
    `IHttpResponse.Body` reader 并返回 Pascal string；nil body 返回 `''`，nil
    response 抛 `EArgumentError`。`test_http_client` 锁住 live response、消费
    reader、nil body 和 nil response 语义，`test_http_contract` 锁住 facade
    可见性，`http_get_client` example 也已改用该 helper。
  - 继续补齐：新增 `HttpReadResponseBodyBytes(Resp)` public helper。它直接消费
    `IHttpResponse.Body` reader 并返回 `TBytes`；nil body 返回空 bytes，nil
    response 抛 `EArgumentError`。`test_http_client` 锁住 live binary body、
    reader 消费、nil body 和 nil response 语义，`test_http_contract` 锁住
    facade 可见性。这个 helper 对齐 Go `io.ReadAll(resp.Body)` / Rust bytes
    取用的基础 ergonomics，但不声明 response streaming、charset decoding 或
    content-type sniffing。
  - 继续收紧：`HttpGetToWriter` / `HttpGetToFile` 现在把被 helper 消费或丢弃的
    response body 纳入 helper ownership。成功 copy、copy 失败、非 2xx rejection
    都会释放 close-capable body；plain `IReader` body 仍走 drain fallback。
    `test_http_client` 用 injected client/closable body 锁住 success、writer
    failure 和 non-2xx 三条路径。这对齐 Go/Rust 中“helper 代替调用方消费 body
    时也负责释放”的资源语义，但不新增 response streaming public API。
  - 继续补齐：新增 `HttpReleaseResponseBody(Resp)` public helper。调用方拿到
    `IHttpResponse` 后如果决定不读取 body，可以显式释放 body ownership：
    close-capable body 会被关闭，plain `IReader` body 会被 drain 到 EOF，nil body
    是 no-op，nil response 抛 `EArgumentError`。`test_http_client` 锁住 close /
    drain / nil body / nil response 语义，`test_http_contract` 锁住 facade
    可见性。这对齐 Go/Rust 常见“未消费响应体也要显式释放/丢弃”的使用面。
    `HttpReadResponseBodyString` / `HttpReadResponseBodyBytes` 会消费并释放 body；
    `HttpReleaseResponseBody` 只用于调用方决定不读取 body 时显式释放。
    当前仍不新增 streaming response API。
  - 继续收紧：`NewResponse(Status, nil, Body)` 现在与 request helper 的 nil
    headers 语义对齐，会创建空 `IHttpHeaders`，调用方可以安全读取或追加
    response headers。`test_http_message` 锁住 helper contract，`test_http_contract`
    锁住 facade 可见性。
  - 本轮补齐：新增 `NewResponse(Status, Headers, BodyText)` 与
    `NewResponse(Status, Headers, BodyBytes)` public helper，并经
    `nextpas.core.http` facade 转发。helper 会复制 fixed body、发布
    `content-length`，拒绝 caller-supplied `transfer-encoding` 与冲突
    `content-length`，并在 `204` / `304` 这类 no-body status 收到非空 fixed body
    时先抛 `EHttpError`、不改写 caller headers；`NewResponse(Status, Headers,
    nil)` 保留 nil-body compatibility，不发布 `content-length`。
    `test_http_message` 锁住 helper contract 与 facade 可见性。
  - 继续收紧：`THttpRequest.Create` 与 `CreateFromRequestTarget` 现在也会把 nil
    headers 规范化为空 `IHttpHeaders`。public helper 仍是推荐入口，但直接使用
    concrete request class 的内部/测试/高级调用方不会再把 nil headers 传播到
    client/H1 code path；`test_http_message` 锁住该 implementation-class contract。
  - 继续收紧：`IHttpClient.Send(Req)` 现在在 public client 入口拒绝 nil
    request，并抛 `EArgumentError`，避免调用方错误穿透到 transport 形成
    access violation；`test_http_client` 锁住该错误语义。
  - 继续收紧：`IHttpClient.Send(Req)` 现在也拒绝 nil transport response。
    injected/default transport 如果从 `RoundTrip` 返回 nil，client facade 会抛
    `EHttpError`，而不是让 nil response 访问穿透成 access violation；
    `test_http_client` 锁住该 transport seam contract。
  - 继续收紧：`NewHttpClient([Transport], Options)` 现在会在 client construction
    边界拒绝负数 `THttpClientOptions.Timeout` 和 `MaxRedirects`，并抛
    `EArgumentError`。`0` timeout 仍表示不设置 client deadline，`0`
    max-redirects 仍表示不允许任何 follow-up redirect；负数不再被默默解释成
    no-timeout 或 redirect error side effect。`test_http_client` 锁住该 options
    validation contract。
  - 继续收紧：`NewHttpServer(Handler[, Transport], Options)` 现在会在 server
    construction 边界拒绝负数 `THttpServerOptions.ReadTimeout` / `WriteTimeout` /
    `IdleTimeout` / `MaxHeaderSize` / `MaxBodySize`，并抛 `EArgumentError`。
    负数不再下沉到 H1 transport 或 TCP foundation。`test_http_contract` 锁住
    facade contract，`test_http_server` 锁住 server consumer gate。
  - 继续收紧：client redirect 现在覆盖 `303 See Other`。`HTTP_STATUS_SEE_OTHER`
    由 `http.base` 与 facade 暴露，`HttpStatusText(303)` 返回 `See Other`；
    `IHttpClient` 跟随 `303` 时按 Go / Rust 常见 client 语义把原请求改为
    `GET` 并丢弃 body。`test_http_base`、`test_http_contract` 与
    `test_http_client` 分别锁住 status text、facade 可见性和 live redirect
    method/body 语义。
  - 继续补齐：`IHttpClient` 现在公开 `CloseIdleConnections` lifecycle seam，
    对齐 Go `http.Client.CloseIdleConnections()` 这类显式收口 idle keep-alive
    连接的使用面。public client 只暴露方法本身，不泄漏 H1 concrete pool；
    transport 通过可选 `IHttpTransportIdleConnections` capability 接住这条语义，
    不支持 idle pool 的 transport 保持安全 no-op。当前 H1 transport 会关闭并清空
    idle pooled connections；`test_http_contract` 锁住 facade 可调用性，
    `test_http_client` 锁住调用后第二次请求必须重新建连的 live 语义。
  - 继续收紧：client 现在也收口 close-capable request body ownership。
    `IHttpClient.Send` 会在最终 round trip 返回或失败后关闭
    `IReadCloser` / `ICloser` / `IStream` request body；`Post` / `Put` /
    `Patch(..., IReader)` shortcut 因为会先把 source body 缓冲成 bytes 以发布
    `Content-Length`，所以也会在 buffering 后立即关闭原始 reader。这样调用方不必
    再额外记住关闭 file/stream request body。`test_http_client` 直接锁住
    `Send` success、transport error 和 reader-shortcut buffering 三条路径。
  - 继续收紧：client `307` / `308` redirect body ownership 现在不再只是复用
    同一个可能已到 EOF 的 reader。若原 body 支持 `IStream`，client 会从第一跳
    发送前的位置 rewind 后再 replay；若非空 body 不能 rewind，则抛
    `EHttpError`，不会静默发出空 body 第二跳。`test_http_client` 用注入
    transport 锁住 seekable replay 和 non-replayable fail-fast。
  - 继续收紧：stale pooled keep-alive connection 的自动重试现在也采用同样的保守
    public 语义。client 只会自动重试 retry-safe 且 body 可重放的请求：方法为
    `GET` / `HEAD` / `OPTIONS` / `TRACE`，或显式带 `Idempotency-Key` /
    `X-Idempotency-Key`，并且 non-empty body 支持 `IStream` rewind。否则会在
    stale pooled connection 失败后直接抛错，不再偷偷发起第二次 round trip，也不再
    把本应重放的 body 静默发送成空 body。`test_http_client` 现在直接锁住
    idempotent replayable success、non-idempotent fail-fast 和 non-replayable
    fail-fast 三条路径。
  - 继续收紧：client redirect follow-up request 现在会继承 caller headers，
    但跨 authority 时会剥离 `Authorization`、`WWW-Authenticate`、`Cookie`、
    `Cookie2` 这类敏感 header；same-authority redirect 会保留这些 header。
    由于 nextPas 把 `content-length` 放在 header 集合里，`301` / `302` / `303`
    改成 bodyless `GET` 时还会删除 `content-length` / `transfer-encoding`，
    避免 follow-up wire 声明 body 却没有 body。`test_http_client` 用注入
    transport 锁住 same-authority preservation 和 cross-authority stripping。
  - 继续收紧：`301` / `302` / `303` redirect 丢弃原 request body 时，client
    会在发起 bodyless follow-up 前关闭原始 close-capable body，并避免 `Send`
    finally 二次 close。`test_http_client` 用注入 transport 锁住 follow-up
    前关闭时序和 exactly-once close。
  - 继续收紧：client redirect follow-up request 现在只在 URL authority
    改变时删除 caller-specified `Host` header。relative / same-authority
    redirect 会保留调用方的 Host override；omitted port 与 scheme 默认端口
    等价，例如 `http://example.test` -> `http://example.test:80` 仍视为同一
    effective authority。absolute 或 network-path cross-authority redirect
    仍删除旧 Host，让 transport 从新 URL 派生 wire host。`test_http_client`
    用注入 transport 锁住 relative redirect 与 default-port redirect 的
    Host ownership。
  - 继续补齐：新增 headers-level `SetBasicAuth(Headers, Username, Password)`
    与 `SetBearerAuth(Headers, Token)` public helper，并通过 `nextpas.core.http`
    facade 转发。它们对齐 Go `Request.SetBasicAuth` 与 Rust client 常见
    basic/bearer auth ergonomics，但保持在 header helper 层，不引入完整
    request builder；nil headers 抛 `EArgumentError`，已有 `Authorization`
    会被替换。`test_http_headers` 锁住 header contract，`test_http_contract`
    锁住 facade 可见性，`test_http_client` 锁住 live `IHttpClient.Send`
    转发后的 wire/header 可见性。
  - 继续补齐：新增 `HttpStatusIsInformational` / `HttpStatusIsSuccess` /
    `HttpStatusIsRedirect` / `HttpStatusIsClientError` /
    `HttpStatusIsServerError` public helper，并通过 facade 转发。它们对齐
    Rust `StatusCode` 常见 status-class ergonomics，避免 client/server 调用方
    重复手写 magic range checks；helper 只做 `1xx` 到 `5xx` range 分类，
    不改变 `HttpStatusText`、wire status 或 response 行为。`test_http_base`
    锁住边界值，`test_http_contract` 锁住 facade 可见性。
  - 继续补齐：新增 `HttpWriteResponseString(Writer, Status, ContentType, Body)`
    public helper，并通过 facade 转发。它给 handler 的常见 fixed string response
    提供一条窄入口：nil writer 抛 `EArgumentError`；`1xx` 会抛
    `EHttpError`，因为该 helper 只写 final response；非空 body 配 `204` / `304`
    在提交前抛 `EHttpError`；空 `204` / `304` 不写 entity headers；body-permitted
    final response 才发布可选 `content-type` 与固定 `content-length`。返回值是
    writer 接收的 body bytes，不是完整 wire bytes。`test_http_h1writer`
    锁住精确 wire、空 body、nil writer、no-body status pre-commit、informational
    rejection、short-progress retry 与 zero-progress `EIOError` 语义，
    `test_http_contract` 锁住 facade 可见性。本 helper 不改
    `IHttpResponseWriter` interface，也不引入 JSON/form/error/redirect helper
    family；这些更高层 helper 需要先单独定义内容类型、编码、错误 body 与 redirect
    ownership contract。
  - 继续收紧：client 跟随 redirect 时，现在会在 follow-up round trip 前释放
    上一跳 redirect response body。支持 `IReadCloser` / `ICloser` / `IStream`
    close 语义的 body 会被关闭；只有 plain `IReader` 能力的 body 会被 drain
    到 EOF。`test_http_client` 用注入 transport 分别锁住 close-capable body
    和 non-closeable body 的 release 语义。后续又补齐 error-path proof：
    `too many redirects`、missing `Location`、unsupported absolute scheme 在
    抛出 `EHttpError` 前同样释放被丢弃的 redirect body，避免 custom/future
    streaming transport 在 redirect 路径上泄漏响应 body 或污染连接复用。
  - 继续收紧：relative redirect `Location` 现在会在 client redirect 层解析
    path/query/fragment，再构造 follow-up request。live H1 wire path 和显式注入
    `IHttpTransport` 的 transport-visible request 都已证明 `/new?x=...` 不会把
    query 留在 `Url.Path` 里，后续 H2/H3 transport seam 也能看到拆分后的
    `Path` / `RawQuery`。
  - 继续收紧：network-path redirect `Location`（例如
    `//redirect.test/new?from=network`）现在会继承原请求 scheme，同时替换
    authority 并拆分 path/query。显式注入 `IHttpTransport` 的 proof 锁住
    follow-up request 的 `Scheme`、`Host`、`Path`、`RawQuery` 和 `QueryParam`
    可见性，避免 future H2/H3 transport 继续收到 base host 或未解析 path。
  - 继续收紧：absolute redirect scheme 现在按 case-insensitive `http` /
    `https` 匹配，并在 follow-up request 中规范成小写；unsupported
    absolute scheme 会在第二次 round trip 前抛 `EHttpError`，包括
    `ftp://...`、`ftp:/...` 与 `mailto:...` 这类带 scheme 但不应被当作
    relative target 的 `Location`。显式注入
    `IHttpTransport` 的 proof 锁住 `HTTP://redirect.test/...` 不再被误当成
    relative target，也锁住 unsupported scheme 不会静默落到 base authority。
  - 继续收紧：path-relative redirect `Location`（例如 `next?from=...`）
    现在会按 base URL 目录合并 path，而不是把 follow-up path 变成裸 `next`。
    显式注入 `IHttpTransport` 的 proof 锁住 `/dir/old` -> `/dir/next`
    语义，避免 H1 request-target 和 future H2/H3 path authority seam 分叉。
  - 继续收紧：relative redirect merged path 现在会移除 dot segments。显式注入
    `IHttpTransport` 的 proof 锁住 `/dir/sub/old` + `../next?from=dot`
    解析成 `/dir/next`，避免 transport 或 future protocol implementation
    被迫自己解释 `..` path segments。
  - 继续收紧：fragment-only redirect `Location`（例如 `#section`）现在只更新
    follow-up request 的 fragment，并保留原请求 path/query。显式注入
    `IHttpTransport` 的 proof 锁住 `/dir/old?from=base` + `#section`
    仍暴露 `Path=/dir/old`、`RawQuery=from=base`、`Fragment=section`；
    H1 writer 仍只发送 path/query，不把 fragment 放入 request-target。
  - 暂不做：不引入完整 fluent `IHttpRequestBuilder`。当前 helper 已覆盖低风险
    ergonomics 缺口；per-request timeout、redirect override、form/json body helper、
    response charset decoding、streaming/chunked request body ownership 等需要更明确
    contract 后再扩。
  - Benchmark truth 继续收紧：std-only Rust comparator 仍标记为
    `impl=rust_std` / `rust_profile=std_only`，同时新增可选 Cargo-based
    Hyper/Tokio comparator smoke，输出 `impl=rust_hyper` /
    `rust_profile=hyper_tokio`、`rust_http_stack=hyper_http1`、
    `rust_runtime=tokio_multi_thread`。这补上了真实 Rust HTTP stack 的
    runner seam，但仍不声明代表完整 Rust 生态性能排名。
  - Benchmark truth 继续收紧：nextPas `bench_server`、Go `net/http` comparator、
    Rust std-only comparator 与 Hyper/Tokio comparator 现在都拒绝显式非法
    `--workload`，输出 `invalid --workload` 诊断并非零退出。单体 comparator
    不再把拼错的 workload 静默当成 `no_url`，避免手工 smoke 或报告捕获生成
    可误读的 benchmark row。
- `http.base`、headers、URL、message、router、middleware、server、H1 parser/scan/fast/writer 已有较强 focused 覆盖。
- `http_get_client` 现在也有 focused runnable example smoke：测试会先启动
  `http_hello_server` 的保留 loopback 端口，再通过 `NEXTPAS_HTTP_GET_URL`
  运行 client example，验证它不会依赖固定 `8080`，并能打印 `status-code=200`
  与 hello response body。
- `http_server_options_demo` 现在也有 focused runnable example smoke：测试会自动 build example、启动外部 server 进程，并验证 `/health`、`/hello/world`、`POST /echo` 与 oversize body `413` rejection。
- `http_websocket_echo_demo` 现在也有 focused runnable example smoke：测试会自动 build example、启动外部 server 进程，完成 `/ws` WebSocket handshake，并验证 masked text frame -> server text echo。
- `THttpClientOptions.Default` / `THttpServerOptions.Default` 现在由 `test_http_base` 直接锁定，其中 `THttpServerOptions.Default.Backend = TCP_SERVER_BACKEND_THREADED` 也已有 focused proof。
- `IHttpServer` 现在也有 focused 生命周期 contract shape 覆盖：public interface 可直接读取 `IsRunning`，pre-listen `LocalAddr` 稳定返回 `0.0.0.0:0` placeholder，`Shutdown` 在未监听前仍保持安全。
- `IHttpServer` 现在也有 Linux `epoll` backend focused differential proof：`THttpServerOptions.Backend := TCP_SERVER_BACKEND_EPOLL` 时，simple GET、keep-alive 复用、fixed/chunked same-write pipelining、keep-alive `Content-Length` garbage tail / truncated follow-up line / truncated follow-up headers 的 follow-up `400` 语义、keep-alive `Content-Length` partial follow-up line / partial follow-up headers 后续可补全为合法第二请求、keep-alive plain chunked garbage tail / truncated follow-up line / truncated follow-up headers 的 follow-up `400` 语义、keep-alive plain chunked partial follow-up line / partial follow-up headers 后续可补全为合法第二请求、chunked trailer-complete keep-alive garbage tail / truncated follow-up line / truncated follow-up headers 的 follow-up `400` 语义、chunked trailer-complete same-write pipelining、chunked trailer-complete partial follow-up line / partial follow-up headers 后续可补全为合法第二请求、hijack ownership、hijack 后异常不补写 `500`、committed response 后异常不补写 `500`、real-socket write-timeout backpressure safe-close / no-follow-up-consume、以及 real-socket queued follow-up `400/413/431/417/501` 在 backpressure 下仍保持 `200 -> error` wire order 的 live 语义都与 threaded 路径或 poll seam 契约保持一致；同一组 queued follow-up `400/413/431/417/501` real-socket wire-order proof 现在也已在默认 threaded backend 直接锁定。fixed-length request body 的 `MaxBodySize` 契约也已直接收口成 explicit `413 Payload Too Large`，并且 threaded / epoll 两条路径都会在拒绝前阻止 handler 进入；chunked ingress 跨 chunk 越限、且 terminal chunk 尚未到达时，`test_http_security` 现在也直接锁住 threaded / epoll 两条 raw-wire 路径都会提前返回 explicit `413`。`test_http_security` 还新增了代表性 request-validation / malformed-framing live parity：`Content-Length + Transfer-Encoding: chunked` 两种 header 顺序都会返回 `400`，duplicate `Content-Length` 与 negative `Content-Length`、generic malformed request、`HTTP/1.1 missing Host`、`HTTP/0.9 / no-version`、`CRLF injection / request-line splitting`、`null-byte header`、very long method、`Content-Length + Connection: close + extra bytes after body`、fixed-length request body EOF truncation、request-line EOF truncation 与 headers EOF truncation 现在也都已在 threaded / epoll raw-wire ingress 路径锁到 explicit `400`，unsupported transfer-coding before chunked -> `501`、`chunked`-must-be-final transfer-coding -> `400`、invalid chunk size -> `400`、malformed chunk extension -> `400`、missing chunk-data CRLF -> `400`、`chunked + Connection: close + extra bytes after terminal chunk` -> `400`、malformed trailer field -> `400`、oversize trailer -> `431`、header field over `MaxHeaderSize` -> `431`、request-target over `MaxHeaderSize` -> `431`；chunk truncation 的 epoll live parity 现在已经覆盖 chunk-extension / chunk-size-line / terminal-chunk-ending / terminal-chunk-extension / terminal-chunk-ending-after-extension / chunk-data EOF 等一整族边界，trailer truncation 的 epoll live parity 也已经覆盖 section / field-name / separator / empty-value / whitespace / field-line / field-CR / section-CR 等 EOF 边界；此外 request-side `IdleTimeout` 现在也已有 live-socket truth：slowloris partial request、partial fixed-length body stall、partial chunk-size-line stall、partial chunked body stall、partial chunked trailer stall 都会最终安全关闭，且不会误进入成功 handler 响应；standalone direct-error 在 backpressure 尝试下现在也已有代表性 live truth：malformed `400`、payload-too-large `413`、header field over `MaxHeaderSize` 的 `431`、request-target over `MaxHeaderSize` 的 `431`、`chunked`-must-be-final malformed `400`、invalid chunk-size malformed `400`、missing chunk-data CRLF malformed `400`、malformed trailer field `400`、truncated trailer field line EOF `400`、oversize trailer `431`、unsupported `Expect` `417` 与 unsupported transfer-coding `501` 在 threaded / epoll 两条路径上都会安全关闭，wire 上至多暴露一条原始 status-line 前缀，不会追加 synthetic `500`；同时 `Content-Length` keep-alive garbage tail / truncated follow-up request line / truncated follow-up headers、plain chunked keep-alive garbage tail / truncated follow-up request line / truncated follow-up headers、以及 chunked trailer-complete keep-alive garbage tail / truncated follow-up request line / truncated follow-up headers 现在也都有 epoll raw-wire proof，锁定首个 `200 / echo:5` 之后 follow-up malformed request 仍返回 `400`，queued follow-up unsupported transfer-coding 会保持首个响应 body 在前、follow-up `501` 在后，queued follow-up unsupported `Expect` 会保持首个响应 body 在前、follow-up `417` 在后，queued follow-up header-too-large `431` 会保持首个响应 body 在前、follow-up `431` 在后，而 queued follow-up payload-too-large `413` 也会保持首个响应 body 在前、follow-up `413` 在后。
- `IHttpServer` 现在还有 `Expect` request-side live contract：默认 threaded 与 Linux `epoll` backend 都会在 headers 完整且请求确实还声明有 body 时先返回单条 `HTTP/1.1 100 Continue`，随后继续读取 body，并把最终 body 原样交给 handler；`test_http_security` 现在也已直接锁住 fixed-length 正向 raw-wire 顺序：先收到 interim `100 Continue`，body 到达前不会误进 handler，也不会提前返回 final `200`，而 body 送达后才返回 final `200`；这条契约现在不仅覆盖 fixed-length body，也直接覆盖 chunked ingress：`Expect + Transfer-Encoding: chunked` 在 security 层现在也已有 direct raw-wire proof，先收到 interim `100 Continue`，chunked body 到达前不会误进 handler，也不会提前返回 final `200`，完整 chunked body 送达后才返回 final `200`，且 handler 能读到解码后的 chunked body；如果 chunked ingress 在收到 `100` 之后跨 chunk 越过 `MaxBodySize`，security 层同样直接锁住最终会返回 `413 Payload Too Large` 且不会进入 handler；如果 interim `100` 已发出后随即收到 invalid chunk-size，security 与 server 两层 focused proof 现在也直接锁住最终会返回 `400 Bad Request`、不会重复发 `100`、不会误回 `200`，且 handler 不会进入；后续又把相邻 chunk framing malformed 补成了 direct truth：如果 interim `100` 已发出后收到 malformed chunk extension 或 missing chunk-data CRLF，security 与 server 两层 focused proof 现在同样直接锁住最终会返回 `400 Bad Request`、不会重复发 `100`、不会误回 `200`，且 handler 不会进入；如果 interim `100` 已发出后收到 malformed trailer field、truncated trailer field-name EOF、truncated trailer separator EOF、truncated trailer empty-value CR EOF、truncated trailer empty-value EOF、truncated trailer empty-value section CR EOF、truncated trailer whitespace CR EOF、truncated trailer whitespace EOF、truncated trailer whitespace section EOF、truncated trailer whitespace section CR EOF、truncated trailer field line EOF、truncated trailer field CR EOF、truncated trailer section EOF、truncated trailer section CR EOF、或 oversize trailer，security 与 server 两层 focused proof 现在也分别直接锁住最终会返回 `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `400 Bad Request` / `431 Request Header Fields Too Large`、不会重复发 `100`、不会误回 `200`，且 handler 不会进入；而如果 interim `100` 已发出后 body 只到达一部分就 stall，或者 body 一个字节都不再到达，threaded / epoll 两条 live path 现在也都直接锁住会按 request-side `IdleTimeout` 安全关闭，不追加 final status-line，更不会误补 synthetic `500`；`test_http_server` 现在也把同一条 truth 直接收口成 public-contract focused proof：fixed-length / chunked partial-body stall、zero-progress stall、after-interim invalid chunk-size final `400`、after-interim malformed chunk extension / missing chunk-data CRLF final `400`、以及 after-interim malformed trailer field / truncated trailer field-name EOF / truncated trailer separator EOF / truncated trailer empty-value CR EOF / truncated trailer empty-value EOF / truncated trailer empty-value section CR EOF / truncated trailer whitespace CR EOF / truncated trailer whitespace EOF / truncated trailer whitespace section EOF / truncated trailer whitespace section CR EOF / truncated trailer field line EOF / truncated trailer field CR EOF / truncated trailer section EOF / truncated trailer section CR EOF / oversize trailer `400/400/400/400/400/400/400/400/400/400/400/400/400/400/431` 在 threaded / epoll 两条路径都会阻止 handler 进入，并保持正确的 wire 语义；反过来，如果请求根本没有声明 body，目前也已有 direct live proof，且最小分支已覆盖到一般 no-body request、HEAD method、以及 transfer-coding error 交互：`Content-Length: 0 + Expect: 100-continue`、普通 no-length `POST + Expect: 100-continue`、no-length `HEAD + Expect: 100-continue`、`Expect + Transfer-Encoding: gzip, chunked`、以及 `Expect + Transfer-Encoding: chunked, gzip` 都已直接锁住不会误发 interim `100 Continue`；其中 transfer-coding error 两条路径会分别直接落到 final `501 Not Implemented` 与 final `400 Bad Request`，HEAD case 则同时锁住 response 仍保持 bodyless wire contract；只要 `Expect` header value 的 comma-separated member 里包含 `100-continue`（包括 duplicate-member case），就仍会按同一契约发出 interim `100 Continue`；如果 `Expect` 重复出现在多条 header-line 上，server 现在也会聚合所有 `Expect` values 判定，因此后续 header-line 里的 unsupported member 仍会把请求直接提升成 final `417 Expectation Failed`，不会因为第一条 `100-continue` 就误发 interim `100`；如果 `Content-Length` 已经在 headers 阶段明确超过 `MaxBodySize`，两条路径都会直接返回 final `413 Payload Too Large`，不会误发 `100 Continue` 再白收 body；如果 `Expect` 含有 unsupported member，两条路径都会在 headers-stage 直接返回 final `417 Expectation Failed`，不会进 handler，也不会先发 `100 Continue`。
- `test_http_security` 现在也把 `Expect` duplicate-member 与 bodyless/no-length 变体补成了 direct raw-wire proof：duplicate `100-continue` member 仍会先返回单条 interim `100 Continue`，而 `Content-Length: 0`、普通 no-length `POST`、以及 no-length `HEAD` 都不会误发 interim `100 Continue`；`HEAD` 变体同时继续保持 bodyless wire contract。
- `Expect` after-interim trailer EOF 邻接链已完成审计并闭合：malformed trailer field、field-name EOF、separator EOF、empty-value 系列、whitespace 系列、field-line EOF、field-CR EOF、section EOF、section-CR EOF 与 oversize trailer 都已经在 `test_http_security` / `test_http_server` 的 threaded 与 Linux `epoll` 两条路径上有 focused proof；下一步不再继续铺同型 trailer EOF parity，而应转向 keep-alive request-tail contract 决策。
- `bench_http_server` benchmark evidence summary: `test_http_benchmarks` 覆盖
  nextPas、Go `net/http`、Rust std-only 与可选 Hyper/Tokio comparator smoke，
  并锁住 runner / snapshot / H1 parser flag-matrix 的核心 truth markers；详细
  command matrix、workload rows 和历史结果放在 `BENCHMARKS.md`，不在 API 矩阵
  复制。Rust std-only 行标记为 `impl=rust_std` / `rust_profile=std_only`，
  Hyper/Tokio 行标记为 `impl=rust_hyper` / `rust_profile=hyper_tokio` /
  `rust_http_stack=hyper_http1` / `rust_runtime=tokio_multi_thread`；这些是
  本地 benchmark evidence，not a permanent ranking。
- `bench_fullchain` evidence 已覆盖 `middleware_noop` row，并用
  `observed_middleware_hits` 区分 middleware dispatch 成本；详细 workload
  contract 仍只放在 `BENCHMARKS.md`。
- `run_server_comparison.sh` 与 `capture_server_comparison_snapshot.sh` 还会记录
  `include_hyper`、`cargo_version`、`hyper_cargo_lock_sha256`、thread clamp、
  read-mode 和 response-body markers；`test_http_benchmarks` 锁住这些 marker，
  避免手工报告误读 Rust std-only / Hyper seam 或丢失环境事实。
- `test_http_benchmarks` 现在还用 source-contract smoke 锁住 H1 server policy 热路径 helper：`ShouldKeepAlive`、`ParserErrorStatus` 与 `ShouldSendContinueResponse` 保持 `inline`，覆盖 keep-alive、parser-error 与 `Expect: 100-continue` 决策入口；`HeaderPolicyErrorStatus` 和大型 server state-machine 仍保持非 inline，避免代码膨胀。
- `bench_router` 现在也有 focused benchmark smoke：测试会自动 build `bench_router`，用 `NEXTPAS_BENCH_FILTER=handler dispatch` 和小迭代上限验证输出包含 `operation=http.router.dispatch`、`handler dispatch`、`ns/op` 与 `ops/s`；`docs/http/BENCHMARKS.md` 已记录本机 `THttpRouter.ServeHTTP` 静态路由 + no-op handler dispatch row。
- `bench_h1writer` 现在也有 focused benchmark smoke：测试会自动 build `bench_h1writer`，用 `NEXTPAS_BENCH_FILTER=fixed 200 13B`、`NEXTPAS_BENCH_FILTER=headers only 200`、`NEXTPAS_BENCH_FILTER=headers block 200 6 headers` 和 `NEXTPAS_BENCH_FILTER=status lines common errors` 的小迭代上限验证输出包含 `operation=http.h1writer.serialize`、真实 benchmark run row、`ns/op` 与 `ops/s`；`docs/http/BENCHMARKS.md` 已记录本机 `TH1ResponseWriter` fixed `200 OK` header-only、6-header block、common error status-line 与 13B body serialization rows。
- `TH1ResponseWriter.WriteStatusLine` 现在对常见状态码使用固定 status-line fast path，覆盖 `100/101/103/200/201/204/301/302/304/400/401/403/404/405/413/417/431/500/501/502/503`，未知状态仍走 `IntToStr` + `HttpStatusText` fallback；`TH1ResponseWriter.WriteAllHeaders` 现在也会在常见 header line 上用栈缓冲物化整行；`TH1ResponseWriter.WriteHeaderBlock` 现在会先尝试把小 header section 与最终空行聚合为一次 write-all invocation，超出栈阈值时在写出前回退旧逐行路径；`test_http_h1writer` 继续锁住 200/404/1xx/101/204/304/HEAD/short-writer/chunked 精确 wire contract，并直接覆盖 common status-line exact bytes / write-call contract、unknown status fallback、fixed `431` short-writer proof、small header block exact bytes / write-call contract 与 large header block fallback proof，`test_http_benchmarks` 继续锁住 H1 writer benchmark rows、known status-line source-contract 和 compact helper source-contract。
- `bench_h1outbound` 现在也有 focused benchmark smoke：测试会自动 build `bench_h1outbound`，用 `NEXTPAS_BENCH_FILTER=buffer write+drain 1KB` 和小迭代上限验证输出包含 `operation=http.h1outbound.drain`、`buffer write+drain 1KB`、`ns/op` 与 `ops/s`；同一 suite 还用 source-contract smoke 锁住 `TH1OutboundBuffer.PendingBytes`、`IsEmpty` 与 `Advance` 的 hot-helper `inline` 形状，避免该 response-drain 热路径回退；`test_http_benchmarks` 现在还直接锁住 H1 server threaded / poll response path 不再把 `IH1OutboundBuffer` 额外包进 generic `TBufferedWriter`，server 侧响应 writer 直接写入 outbound drain buffer；`docs/http/BENCHMARKS.md` 已记录本机 `NewH1OutboundBuffer` 1 KiB write + `DrainAllTo` in-memory drain row 和 direct outbound response path focused evidence。
- `bench_fullchain` 现在也有 focused benchmark smoke：测试会自动 build `bench_fullchain`，用 `NEXTPAS_BENCH_MAX_ITERS=128` 和 narrowed `NEXTPAS_BENCH_FILTER` 验证 plaintext、direct-handler、JSON/router、echo、sink、param-route 与 middleware_noop rows 的 `operation=http.fullchain.keepalive`、`client_read_mode=buffered`、workload、body-size、dispatch-path、handler-hit、`observed_middleware_hits`、iterations/completed、elapsed/ns/op/req/s 与 filter markers；`docs/http/BENCHMARKS.md` 已记录本机 plaintext keep-alive full-chain row，并标明该 row 是单连接同步 ping-pong，不直接替代多 client server comparison。
- `bench_fullchain` 现在也会在 `NEXTPAS_BENCH_FILTER` 没有命中任何 scenario 时
  fail-fast：保留 `bench_filter=` marker 与 `No matching full-chain scenarios.`
  诊断，但退出码改为非零，不再把 zero-row run 伪装成成功 benchmark evidence。
  `test_http_benchmarks` 直接锁住这条 no-match filter contract。
- H1 server ingress 现在已接入保守 fast path：完整 HTTP/1.1、恰好一个非空 `Host`、无 `Expect` / `Transfer-Encoding`、无 body 的普通请求可绕过 llhttp adapter 分配路径；重复 `Host` 会在 fast/llhttp metadata 中保留为 ingress policy flag，并在 handler 前返回 explicit `400`。显式 `Connection: keep-alive` 现在也保持 fast-path compatible，避免旧的 fast-parse-then-llhttp double parse，而 `Connection: close`、`upgrade` 或其他 connection-policy token 仍回退既有 llhttp/server validation。非法同长度 method、任意 transfer-coding、重复 `Content-Length` 与 body 不完整都会 fast-fail 并回退既有 llhttp/server validation。`test_http_h1fast` 锁住 fast parser fallback 与 connection-policy flags，`test_http_server` 275-case threaded / epoll gate 锁住 server contract，`test_http_benchmarks` 锁住 `adapter no-url` narrowed benchmark rows；`docs/http/BENCHMARKS.md` 已记录本机 `adapter_no_url` 优化证据：same-day median 从 `12280 ns/op` 到 `11022 ns/op`，但该 workload 主要作为 nextPas 内部 fast-gate 差分，不作为跨语言 apples-to-apples 排名。
- H1 fast lazy headers 现在也有 focused proof：`TFastLazyHeaders.Get` / `Has` / `Count` / `GetAll` 在未 materialize 时会直接扫描 raw header block，不再为了 single-header lookup、count-only access 或 same-name multi-value lookup 强制 `EnsureMaterialized`；其中 `Has` 现在走纯 raw presence lookup，不再通过 first-value lookup 构造临时 value string。case-insensitive name、空 header value 的 `Has=True`、`Get` 首值、缺失 header、raw `Count`、raw `GetAll` duplicate order，以及 raw lookup 后 `ForEach` materialization 仍保留 header 遍历语义。`IsValidHeaderValueFast` 同时修正了 `ALen=0` 下 `SizeUInt` loop-bound underflow，空 header value 不再误触发 fast parser fallback。`test_http_h1fast`、`test_http_benchmarks` 与 `test_http_server` 已分别锁住 parser behavior、source-contract/benchmark rows 和 server contract。
- H1 server request construction 现在使用 `THttpRequest.CreateFromRequestTarget` 延迟 request-target URL projection；handler/router/middleware 读取 `Req.Path` / `Req.RawQuery` / `Req.QueryParam` 时只做 request-target path/query 轻量拆分，读取 `Req.Url` 时仍按 `TUrl.ParseRequestTarget` materialize 完整 URL record。`test_http_message` 直接锁住 origin-form、absolute-form、asterisk-form、authority-like target、relative target、fragment/query 边界与 invalid absolute port 行为，`test_http_benchmarks` 用 source-contract 锁住 direct accessor 不再强制完整 URL materialization，`test_http_server` gate 继续锁住 handler-visible URL materialization。
- H1 parser request metadata 现在在 header parse 阶段增量缓存，并只在 headers-complete 校验通过后发布最终 metadata，不再在 `BuildRequestMetadata` 中通过 `IHttpHeaders.Get/GetAll` 二次回扫 header store；`Host` / `Connection` / `Content-Length` / `Expect` watched metadata 还会在 llhttp 单 span callback 下直接扫描 captured span，避免额外 value string materialization，`Transfer-Encoding` 保持 combined-string 校验路径以保护错误分类。source-contract 锁住 parser unit 中的 parse-time helper、span fast-path helper、callback hook 和无回扫形状，`test_http_h1parser` 直接覆盖 split/duplicate watched headers 的首值/多值语义、headers-complete 前不发布 partial metadata、chunked trailer 不污染 metadata、以及 span fast path 下 trim/token 语义不漂移，`test_http_server` 继续锁住 `Expect`、`Transfer-Encoding`、missing Host、chunked malformed/oversize 等 server wire contract。`docs/http/BENCHMARKS.md` 已记录 `request metadata` narrowed row：legacy synthetic cost `1321.3 ns/op`，cached synthetic cost `6.1 ns/op`，并记录本轮 `adapter no-url` parser smoke。
- `http.base` 现在也有 `HTTP_STATUS_CONTINUE = 100 / "Continue"`、`HTTP_STATUS_EARLY_HINTS = 103 / "Early Hints"`、`HTTP_STATUS_EXPECTATION_FAILED = 417 / "Expectation Failed"` 与 `HTTP_STATUS_NOT_IMPLEMENTED = 501 / "Not Implemented"` 的 focused proof。
- `TUrl.HostPort` 现在锁住 IPv6 authority bracket contract：`[::1]:port` / `[fe80::1]`，与 `TUrl.ToString` 和 H1 client auto-`Host` header authority 规则保持一致。
- `IHttpClient.Get/Post/Send` 原本已覆盖；本轮补齐 `Put/Delete/Patch/Head` focused 覆盖。
- `HttpGetToWriter` / `HttpGetToFile` 现在也有 focused proof：successful GET body copy 返回 byte count，helper 消费/丢弃 response body 后会释放 close-capable body，file helper 通过同目录临时文件发布最终路径，非 2xx response 抛 `EHttpError` 且不创建 final file，truncated fixed-length body 会清理 temp file。
- `IHttpTransport`、`IHttpServerTransport` 现在既有 focused shape 覆盖，也有 facade runtime 注入覆盖；`IHttpServerTransport.ServeConn` 的 post-handler ownership 返回语义也已锁定，并且 ownership 类型/常量可经由 `nextpas.core.http` facade 直接消费，internal registry 同样已有 focused proof。
- `test_http_contract` 现在也直接锁定了当前 chunked trailer 公共契约：single / multiple trailer declaration 都会保留原始 `Trailer` 声明头文本，handler 仍能读到解码后的 body，但实际 trailer field 不会泄漏进普通请求头。
- `IHttpServerSessionFactoryWithContext` 与 `ITcpServerSessionContext` alias 现在也有 focused proof：HTTP transport 会优先走 context-aware session factory，transport 侧可以看到 foundation 提供的 `WorkerHandoff`，而且 context-aware H1 session 现在已经直接暴露 `ITcpServerPollDrivenSession` seam，并且同连接上两个已完成请求会分成两次独立 handoff，而不是整连接一次 worker `Run`；request-side `IdleTimeout` 现在也有 poll-driven focused parity proof：不仅第一个 request byte 到达前会暴露有限 read-side `WakeDeadline`，partial fixed-length body stall、partial chunk-size-line stall、partial chunked body stall 与 partial chunked trailer stall 也会沿用同一个 request-parse deadline 收口，超时后安全关闭并把 `WakeDeadline` 清回 infinite；partial request progress 不会偷重置 read deadline。successful response 也已经能在 completion wake / `peWritable` 上做 reactor-owned drain，`WriteTimeout > 0` 时还会通过 `WakeDeadline` 收口 stalled drain，successful timed drain 结束后会把 `WakeDeadline` 清回 infinite，而 stalled/partial timed drain 的 timeout-close 路径同样会把 `WakeDeadline` 清回 infinite，不会留下过期 deadline；partial-write timed drain 现在也有 focused proof：只有真正写出新字节时才会 re-arm write deadline，而纯 would-block / deadline-close 不会偷改 deadline，也不会偷跑 buffered follow-up request；untimed path 还新增了 active+1 queued 的有界有序 response queue proof，并直接锁定 queued follow-up `400/413/431/417/501` 都会保持在前一个响应之后按 wire order 排出，standalone direct `400/413/431/417/501` 也都会先进入 reactor-owned nonblocking drain，再由后续 `peWritable` 完成，不再回退 sync socket write，其中 `chunked`-not-final transfer-coding malformed `400` 现在也已有 focused poll-driven writable-drain proof，queued follow-up `400/413/431/417/501` 则已在 Linux `threaded/epoll` real-socket/backpressure 路径得到 live 证明。
- `IHttpHijacker` 已有 facade alias、writer 行为、server ownership 覆盖，以及 hijack 后异常路径下 server 不再补写 `500` / 不再回收连接的 focused proof；WebSocket upgrade 后 handler 抛异常时，server 同样不会追加 synthetic `500`，且 handler-owned websocket 仍可继续收发 frame。
- facade callback aliases、`MiddlewareFunc`、query helper 与 server/client overload 现在有直接 focused smoke，可从 `nextpas.core.http` 单一门面消费。
- `nextpas.core.http` facade 现在也有 direct status-constant parity proof：`HTTP_STATUS_SWITCHING_PROTOCOLS` / `HTTP_STATUS_EARLY_HINTS` / `HTTP_STATUS_PAYLOAD_TOO_LARGE` / `HTTP_STATUS_NOT_IMPLEMENTED` / `HTTP_STATUS_HEADER_TOO_LARGE` 都可直接经由 facade 消费，并返回正确状态文案。
- `nextpas.core.http` facade 现在也直接转发 static / websocket helper：`ServeFile`、`ServeDir`、`UpgradeWebSocket`、`IWebSocket`、`TWebSocketOptions`、`TWebSocketOpcode`、`TWebSocketFrame`、`WEBSOCKET_DEFAULT_MAX_*` 与 `wsOp*` 枚举值都已有 focused facade proof；`test_http_static` / `test_http_websocket` 现已切到经由 facade 消费这些公开 helper。
- Static serving 现在也有 helper-level MIME focused proof：扩展名匹配大小写不敏感，`.JSON` 会返回 `application/json`，未知扩展名安全回退 `application/octet-stream`。
- WebSocket 现在也有代表性 negative frame proof：server-side `ReadFrame` 会拒绝 unmasked client frame、RSV bit、control-frame payload length > 125、reserved opcode、fragmented control frame、invalid close code、invalid UTF-8 text payload、invalid UTF-8 close reason、standalone continuation frame、16-bit / 64-bit non-canonical payload length、64-bit payload length high-bit 非零、`TWebSocketOptions.MaxFrameSize` frame 超限、以及 `TWebSocketOptions.MaxMessageSize` fragmented message 累计超限，并抛 `EHttpError`，handler 可将 protocol error 映射为 close code `1002`，将 size-limit error 映射为 close code `1009`；非法 client frame 不会被当普通 text/ping/close/continuation frame 继续处理，oversize declared length 也不会进入 payload 分配/读取路径；outgoing `WriteText` 现在会在写出前拒绝 invalid UTF-8 payload，outgoing `Ping` 与 `Close` 也会在写出前拒绝 payload > 125 的 control frame，outgoing `Close` 还会拒绝 invalid close code / invalid UTF-8 reason，不再生成非法 text/close/control frame；同时 fragmented text 的 UTF-8 校验已经从“逐 frame 校验”推进为“final continuation 校验整条累计 text message”，合法跨片 UTF-8 sequence 不再被首片误拒。
- `IHttpRouter` 现在也补齐了 `Connect` / `Trace` 便利方法，和已公开的 `hmConnect` / `hmTrace` method enum 对齐；`test_http_contract` 锁住 interface surface，`test_http_router` 锁住 concrete router dispatch。
- `IHttpMiddleware` / `Chain` / `MiddlewareFunc` 现在也有 nil 输入 focused proof：nil middleware callback、nil chain root handler、nil middleware entry 都会在 assembly 边界显式抛 `EHttpError`，且 `Chain` 在中间步骤抛异常时不会泄漏已构造的 chain。
- `TH1ResponseWriter` 边界覆盖现在包括预设 `Transfer-Encoding`、显式 `Content-Length` flush 路径、`100/101/204/304` no-body status 不注入 chunked，且 no-body / informational status 还会 strip preset chunked `Transfer-Encoding`，避免 handler 预设 framing 泄漏到无 body wire；非 `101` informational response（以 `103 Early Hints` 为代表）不会提交 final response，后续仍可发送 final `200` 与 body；`101` 也有 direct body-write rejection proof、HEAD-style suppress-body 路径不发 body bytes、no-body / chunked-finalized 两条拒绝继续写入路径、以及 short-write 底层 writer 下 header/body/chunked body 的 write-all contract（完整写出或 zero-progress `EIOError`，不再静默截断 framing / body）。
- `IHttpServer` 现在也有 informational response public contract proof：handler 先写 `103 Early Hints` 再写 final `200 OK` 时，threaded / Linux `epoll` 两条 live path 都会保持 `103 -> 200 -> body` wire order，且 `103` 不会被当作 committed final response。
- `IHttpClient` 现在有 focused chunked response / close-delimited response / truncated fixed-length response 读取覆盖，并且 client pooling 已改为依赖 parser 推导出的 keep-alive 语义；`HEAD` response 即使显式带 `Content-Length` 也会保留 header 且不误读 body。
- `H1 parser` 现在有 focused response reuse semantic 覆盖：close-delimited / `Content-Length` / HTTP/1.0 非 keep-alive / truncated fixed-length EOF rejection；`HEAD`-style skip-body + explicit `Content-Length` 也已直接锁定。
- `H1 parser` 现在也有 request-side chunked body focused 覆盖：正常解码、invalid chunk-size、malformed chunk extension、missing chunk-data CRLF、EOF truncation、`CL+TE` conflict 两种顺序的 parser error、以及 trailer 字段不污染普通请求头。
- `H1 parser` 现在也有 request-side transfer-coding order focused 覆盖：`Transfer-Encoding: gzip, chunked` 会被直接判成 unsupported request transfer-coding，而 `Transfer-Encoding: chunked, gzip` 会被直接判成 malformed，因为 `chunked` 不是 final coding。
- `H1 parser` 现在也有 `chunk-extension line EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `chunk-size line EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `terminal chunk ending CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `terminal chunk extension EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `terminal chunk ending after extension EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `terminal chunk ending after extension CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer field-name EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer separator EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer empty-value CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer empty-value EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer empty-value section CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer whitespace EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer whitespace CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer whitespace section EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer whitespace section CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer field line EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer field CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `truncated trailer section CR EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `chunk-data CRLF EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 `terminal 0 chunk ending EOF truncation` focused 覆盖。
- `H1 parser` 现在也有 late trailer byte accounting focused 覆盖，直接锁定 trailer 分段到达时的 byte budget 统计与 `Reset` 清零语义。
- `H1 parser` 现在也有 malformed trailer focused 覆盖：非法 trailer field-name 与 trailer section EOF truncation 都会被直接拒绝。
- `H1 parser` 现在也有 request-side fixed-length body EOF truncation focused 覆盖。
- `H1 parser` 现在也有 request-line / headers EOF truncation focused 覆盖。
- `H1 parser` 现在也有 duplicate `Content-Length` focused 覆盖。
- `H1 parser` 现在也有 `null-byte header` focused 覆盖。
- `H1 parser` 现在也有 generic malformed request focused 覆盖。
- `H1 parser` 现在也有 `HTTP/0.9 / no-version` focused 覆盖。
- `H1 parser` 现在也有 `CRLF injection / request-line splitting` focused 覆盖。
- `H1 parser` 现在也有 `negative Content-Length` 与 `very long method` focused 覆盖。
- `H1 parser` 现在也有 `Content-Length + Connection: close + extra bytes after body` focused 覆盖。
- `H1 parser` 现在也有 keep-alive `Content-Length` garbage tail focused 覆盖：首个合法 fixed-length request 只消费自己的字节，不会被后续垃圾尾巴污染。
- `H1 parser` 现在也有 keep-alive `Content-Length` partial follow-up request-line focused 覆盖：首个合法 fixed-length request 只消费自己的字节，不会被半截下一请求行污染。
- `H1 parser` 现在也有 keep-alive `Content-Length` partial follow-up request-line bridge proof：同样的半截 follow-up line 在后续字节补全后可以合法完成为第二个请求，因此不能被过早当成 malformed tail。
- `H1 parser` 现在也有 keep-alive `Content-Length` partial follow-up headers bridge proof：首个合法 fixed-length request 只消费自己的字节，不会被半截下一请求头污染，且后续字节补全后可以合法完成为第二个请求，因此不能被过早当成 malformed tail。
- `H1 parser` 现在也有 `chunked + Connection: close + extra bytes after terminal chunk` focused 覆盖。
- `H1 parser` 现在也有 keep-alive chunked garbage tail focused 覆盖：首个合法 chunked request 只消费自己的字节，不会被后续垃圾尾巴污染。
- `H1 parser` 现在也有 keep-alive chunked partial follow-up request-line focused 覆盖：首个合法 chunked request 只消费自己的字节，不会被半截下一请求行污染。
- `H1 parser` 现在也有 keep-alive chunked partial follow-up request-line bridge proof：同样的半截 follow-up line 在后续字节补全后可以合法完成为第二个请求，因此不能被过早当成 malformed tail。
- `H1 parser` 现在也有 keep-alive chunked partial follow-up headers bridge proof：首个合法 chunked request 只消费自己的字节，不会被半截下一请求头污染，且后续字节补全后可以合法完成为第二个请求，因此不能被过早当成 malformed tail。
- `H1 parser` 现在也有 keep-alive chunked trailer-complete garbage tail focused 覆盖：完整 trailer section 结束后仍只消费首个合法 request，且 trailer 声明头保留、实际 trailer field 不进入普通请求头。
- `H1 parser` 现在也有 keep-alive chunked trailer-complete valid pipelined next-request focused 覆盖：完整 trailer section 结束后，合法下一请求同样不会污染首个 request，且 trailer declaration / trailer isolation 契约保持不变。
- `H1 parser` 现在也有 keep-alive chunked trailer-complete partial follow-up request-line bridge proof：同样的半截 follow-up line 在后续字节补全后可以合法完成为第二个请求，因此不能被过早当成 malformed tail。
- `H1 parser` 现在也有 keep-alive chunked trailer-complete partial follow-up headers bridge proof：同样的半截 follow-up headers 在后续字节补全后也可以合法完成为第二个请求，同时 trailer declaration / trailer isolation 契约保持不变，因此不能被过早当成 malformed tail。
- `H1 parser` 现在也有 same-read pipelined request isolation focused 覆盖：普通 fixed-length 与 chunked 首请求都只消费自己的字节，不会被同包后续 request 污染。
- `H1 parser` 现在也有 Reset header reuse focused guard：复用 parser 后第二次 parse 不会暴露第一次请求的 stale `Host` header。
- `IHttpServer` 现在有 inbound chunked request focused 覆盖：handler 可读 decoded body、`MaxBodySize` 对 chunked ingress 的跨 chunk 累加超限生效、invalid chunk-size 返回 `400`、malformed chunk extension 返回显式 `400`、missing chunk-data CRLF 返回显式 `400`、chunked/trailer EOF truncation 在 peer half-close 后返回显式 `400`、generic malformed request 返回显式 `400`、`HTTP/1.1 missing Host` 返回显式 `400`、`HTTP/1.0 missing Host` 仍允许、`HTTP/0.9 / no-version` 返回显式 `400`、`CRLF injection / request-line splitting` 返回显式 `400`、`negative Content-Length` 返回显式 `400`、`very long method` 返回显式 `400`、`CL+TE` conflict 两种顺序返回 `400`、duplicate `Content-Length` 返回显式 `400`、`null-byte header` 返回显式 `400`、普通 header field over `MaxHeaderSize` 返回显式 `431` 且不进入 handler、request-target over `MaxHeaderSize` 返回显式 `431` 且不进入 handler、trailer 声明头保留且 trailer 字段不进入普通请求头、oversize trailer 在后续 read 到达时仍受 `MaxHeaderSize` 限制并触发显式 `431`，且异常 chunk 不进入 handler。
- `IHttpServer` 现在也有 request-side unsupported transfer-coding focused 覆盖：`Transfer-Encoding: gzip, chunked` 返回显式 `501`，而 `chunked, gzip` 继续作为 malformed framing 返回显式 `400`。
- `IHttpServer` 现在也有 response-side no-body focused 覆盖：`204/304` raw-wire 响应都不注入 `Transfer-Encoding: chunked`，不强制补 `Content-Length`，也不写 chunk trailer。
- `IHttpServer` 现在也有 HEAD response suppression focused 覆盖：即使 handler 调用了 `Write`，raw-wire 响应也不注入 `Transfer-Encoding: chunked`、不写 chunk trailer、也不发 body bytes；若 handler 显式设置 `Content-Length`，header 也会保留。
- `IHttpServer` 现在也有 committed response exception focused 覆盖：handler 在 `Flush` 后抛异常时，server 只安全关闭连接，不会再追加 synthetic `500`；threaded / epoll 两条路径都已直接锁定。
- `IHttpServer` 现在也有 zero-progress response write failure focused 覆盖：底层 buffered writer 一旦出现 zero-progress write，session 会立即停止，不再继续消费同连接里的后续 pipelined request。
- `IHttpServer` 现在也有 write-timeout/backpressure safety focused 覆盖：`WriteTimeout > 0` 时 session 会在真实 socket drain 前设置 write deadline；同一条 timeout 语义也覆盖 direct error response 路径，因此 parser error / size-limit rejection / unsupported `Expect` 这类直接 `400/413/431/417/501` 响应不会绕过 write-timeout；timeout 若发生在首个响应写出前，不会补写 synthetic `500`；timeout 若发生在部分字节已写出后，也会安全停止 session，且不会继续消费后续 pipelined request；partial timed drain 还直接锁定了 deadline lifecycle：只有写出新字节时才会 re-arm，纯 would-block retry 与 deadline-close 不会重置 deadline，而 timeout-close 后 `WakeDeadline` 会清回 infinite，不会残留过期 deadline；untimed poll-path 现在也直接锁定 queued follow-up `400/413/431/417/501` 会排在先前 undrained response 之后，且 close-after-drain queued error response 不会因为残余 malformed bytes 再多等一轮无意义的 writable wake；real-socket stalled-peer/backpressure 场景在 threaded 与 Linux `epoll` 两条 backend 上都已直接锁定不会追加 synthetic `500`、不会消费后续 pipelined request，malformed follow-up 不会额外漏出 `400`，follow-up `413` / `431` / `417` / `501` 也不会额外漏出，并会在放宽观察窗口内关闭连接；当前 live proof 还直接锁定 wire 上只会看到首个 response status line，且 large response 的 handler-side body production 可以先完整结束，然后才在后续 drain 阶段超时关闭；这条 proof刻意不把 `WriteTimeout=50ms` 冻结成严格 wire-close SLA。
- `IHttpServer` 现在也有 whole-run direct error write-timeout focused 覆盖：malformed `400`、payload-too-large `413`、header-too-large `431`、unsupported transfer-coding `501` 在进入 handler 前都会先 arm write deadline；无论首个错误响应是在首字节前超时，还是已写出部分原始 error status/header bytes 后超时，都不会再追加 synthetic `500` 或第二条 status line。`test_http_security` 现在还补上了 real-socket 视角的代表性 safe-close envelope：对 malformed `400`、payload-too-large `413`、header field over `MaxHeaderSize` 的 `431`、request-target over `MaxHeaderSize` 的 `431`、以及 unsupported transfer-coding `501`，peer 在 backpressure 尝试下要么看到单一原始 status-line 前缀，要么直接看到安全关闭，但不会看到 synthetic `500` 或双 status line。
- `IHttpServer` 现在也有 poll-driven standalone direct error timed partial-timeout focused 覆盖：reactor-owned direct `400/413/431/417/501` error drain 在写出部分原始 error status/header bytes 后超时关闭时，同样保持单一原始 status line，不会追加 synthetic `500`，且 `WakeDeadline` 会在 timeout close 后清回 infinite；其中 `400` 现在已不只覆盖 generic malformed request，也直接覆盖 `chunked`-not-final transfer-coding malformed request。
- `IHttpServer` 现在也有 slow buffered handler focused 覆盖：threaded 与 Linux `epoll` 两条 backend 上，handler 只是在内存 outbound buffer 内慢速生成一个小响应、而真实 socket drain 尚未开始时，即使 handler-side latency 已超过 `WriteTimeout`，响应仍会正常返回 `200`；当前 public contract 把 `WriteTimeout` 约束在真实写 socket 的 drain 阶段，而不是把 handler 内部的 pre-drain 计算时间算成 write-timeout 预算。
- `IHttpServer` 现在也有 `chunk-size line EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `terminal chunk ending CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `terminal chunk extension EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `terminal chunk ending after extension EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `terminal chunk ending after extension CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer field-name EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer separator EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer empty-value CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer empty-value EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer empty-value section CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer whitespace EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer whitespace CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer whitespace section EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer whitespace section CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer field line EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer field CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `truncated trailer section CR EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `chunk-extension line EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `chunk-data CRLF EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `terminal 0 chunk ending EOF truncation` focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `Content-Length + Connection: close + extra bytes after body` focused 覆盖：返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `chunked + Connection: close + extra bytes after terminal chunk` focused 覆盖：返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有一条 server-layer contract proof：非 `Connection: close` `Content-Length` garbage tail 会先完成首个合法 request，再把尾巴作为 follow-up malformed request 返回 `400`；该行为已固定为 keep-alive request-tail contract。
- `IHttpServer` 现在也有 keep-alive `Content-Length` partial follow-up request-line current-truth proof：首个合法 fixed-length request 会先完成并进入 handler，半截下一请求行在 peer half-close 后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive `Content-Length` partial follow-up request-line bridge proof：首个请求的 `200` 会先正常返回，后续若把半截下一请求补全，第二个请求也会继续合法完成。
- `IHttpServer` 现在也有 keep-alive `Content-Length` partial follow-up headers bridge proof：首个合法 fixed-length request 会先完成并进入 handler，半截下一请求头在后续字节补齐后仍可继续完成为合法第二请求，因此不会被过早判成 malformed follow-up。
- `IHttpServer` 现在也有 keep-alive chunked garbage tail contract proof：首个合法 chunked request 会先完成并进入 handler，尾巴随后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive chunked partial follow-up request-line current-truth proof：首个合法 chunked request 会先完成并进入 handler，半截下一请求行在 peer half-close 后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive chunked partial follow-up request-line bridge proof：首个请求的 `200` 会先正常返回，后续若把半截下一请求补全，第二个请求也会继续合法完成。
- `IHttpServer` 现在也有 keep-alive chunked partial follow-up headers bridge proof：首个合法 chunked request 会先完成并进入 handler，半截下一请求头在后续字节补齐后仍可继续完成为合法第二请求，因此不会被过早判成 malformed follow-up。
- `IHttpServer` 现在也有 keep-alive chunked trailer-complete garbage tail current-truth proof：完整 trailer section 结束后的尾巴不会污染首个请求，trailer 声明头仍保留、实际 trailer field 仍不暴露为普通 header，尾巴随后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive chunked trailer-complete valid pipelined next-request focused proof：同一连接中的第二个合法请求会继续完成，且首请求 handler/response/body/trailer contract 不会被污染。
- `IHttpServer` 现在也有 keep-alive chunked trailer-complete partial follow-up request-line bridge proof：首个请求的 `200` 会先正常返回，后续若把半截下一请求补全，第二个请求也会继续合法完成。
- `IHttpServer` 现在也有 keep-alive chunked trailer-complete partial follow-up headers bridge proof：首个 trailer-complete chunked request 的 `200` 会先正常返回，后续若把半截下一请求头补全，第二个请求也会继续合法完成，同时首请求的 trailer declaration / trailer isolation 契约保持不变。
- `IHttpServer` 现在也有 same-write pipelined request isolation focused 覆盖：transport 会保留未消费尾巴，确保前一 request 的 handler/response 与后一 request 分离；该证明现在同时覆盖普通 fixed-length 与 chunked 首请求。
- keep-alive request-tail contract 已固定：fixed-length / plain chunked / trailer-complete chunked 请求在当前 request framing 完成时即完成，未消费 tail bytes 进入下一次 request parse；partial follow-up request-line / headers 在可能补全时不得被提前当成 malformed，后续补齐后可成为合法第二请求；conclusively malformed 或 EOF-truncated follow-up 才返回 follow-up `400`。该 contract 由 `test_http_h1parser`、`test_http_server`、`test_http_security` 三层 focused coverage 共同证明。
- `IHttpServer` 现在也有 malformed trailer focused 覆盖：非法 trailer field-name 与 trailer section EOF truncation 都会返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 fixed-length request body EOF truncation focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 request-line / headers EOF truncation focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 `chunked` must-be-final transfer-coding focused 覆盖：`Transfer-Encoding: chunked, gzip` 返回显式 `400`，且不进入 handler。
- `test_http_security` 现在把 `CL+TE` conflict、invalid chunk size、malformed chunk extension、以及 truncated chunked EOF 都锁成 explicit `400` proof。
- `test_http_security` 现在也把 chunked ingress `MaxBodySize` 越线即 `413` 锁成 raw-wire proof：不必等待 terminal chunk。
- `test_http_security` 现在也把 oversize trailer 仍受 `MaxHeaderSize` 约束锁成 raw-wire explicit `431` proof：threaded / Linux `epoll` 两条路径都会返回显式 `431`，且不会落到 handler。
- `test_http_security` 现在也把 `chunk-size line EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `terminal chunk ending CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `terminal chunk extension EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `terminal chunk ending after extension EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `terminal chunk ending after extension CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer field-name EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer separator EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer empty-value CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer empty-value EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer empty-value section CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer whitespace EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer whitespace CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer whitespace section EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer whitespace section CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer field line EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer field line EOF truncation` 的 direct-error backpressure safe-close 锁成 live proof：threaded / Linux `epoll` 两条路径都只会暴露原始 `400` status-line 前缀，然后安全关闭，不会追加 synthetic `500`。
- `test_http_security` 现在也把 `truncated trailer field CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer section CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `chunk-extension line EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `chunk-data CRLF EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `terminal 0 chunk ending EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也包含 generic malformed request、`HTTP/1.1 missing Host`、`HTTP/0.9 / no-version`、`CRLF injection / request-line splitting`、`negative Content-Length`、`very long method`、`Content-Length + Connection: close + extra bytes after body`、`chunked + Connection: close + extra bytes after terminal chunk`、duplicate `Content-Length`、`null-byte header`、missing chunk-data CRLF、malformed trailer、fixed-length request body EOF truncation、`Expect: 100-continue + declared oversize -> final 413 without interim 100`、`repeated Expect headers + unsupported member -> final 417 without interim 100`、以及 request-line / headers EOF truncation 的 raw-wire explicit `400` / `413` / `417` proof。
- `test_http_security` 现在也把普通 header field over `MaxHeaderSize` 与 `request-target over MaxHeaderSize` 都锁成 raw-wire explicit `431` proof：在受控小 `MaxHeaderSize` 下，两类 oversized header-budget 输入在 threaded / Linux `epoll` 两条路径都会直接返回显式 `431`；`test_http_server` 同时继续锁住更窄的 server-layer 语义：对应分支不会进入 handler。
- `test_http_security` 现在也有 Linux `epoll` backend 的代表性 malformed / validation live parity proof：generic malformed request、`HTTP/1.1 missing Host`、`HTTP/0.9 / no-version`、`CRLF injection / request-line splitting`、`null-byte header`、very long method、`Content-Length + Connection: close + extra bytes after body`、unsupported transfer-coding before chunked -> `501`、invalid chunk size -> `400`、missing chunk-data CRLF -> `400`、truncated trailer section CR EOF -> `400`、oversize trailer -> `431`。
- `test_http_security` 现在也有 queued follow-up malformed request 的 wire-order proof：threaded / Linux `epoll` 两条 raw-wire 路径都会先排出首个 `200` 响应的 body 前缀，再把 follow-up `400 Bad Request` 放在其后，且不会追加 synthetic `500`。
- `test_http_security` 现在也有 queued follow-up unsupported transfer-coding 的 wire-order proof：threaded / Linux `epoll` 两条 raw-wire 路径都会先排出首个 `200` 响应的 body 前缀，再把 follow-up `501 Not Implemented` 放在其后，且不会追加 synthetic `500`。
- `test_http_security` 现在也有 queued follow-up unsupported `Expect` 的 wire-order proof：threaded / Linux `epoll` 两条 raw-wire 路径都会先排出首个 `200` 响应的 body 前缀，再把 follow-up `417 Expectation Failed` 放在其后，且不会追加 synthetic `500`。
- `test_http_security` 现在也有 queued follow-up header-too-large 的 wire-order proof：threaded / Linux `epoll` 两条 raw-wire 路径都会先排出首个 `200` 响应的 body 前缀，再把 follow-up `431 Request Header Fields Too Large` 放在其后，且不会追加 synthetic `500`。
- `test_http_security` 现在也有 queued follow-up payload-too-large 的 wire-order proof：threaded / Linux `epoll` 两条 raw-wire 路径都会先排出首个 `200` 响应的 body 前缀，再把 follow-up `413 Payload Too Large` 放在其后，且不会追加 synthetic `500`。
- `test_http_security` 现在也有 keep-alive `Content-Length` garbage tail safe-handling proof：首个请求先完成，尾巴随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive `Content-Length` partial follow-up request-line safe-handling proof：首个请求先完成，半截下一请求行随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive `Content-Length` partial follow-up request-line bridge proof：首个请求的 `200` 会先正常返回，后续若把半截下一请求行补全，第二个请求也会继续合法完成；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive `Content-Length` truncated follow-up headers safe-handling proof：首个请求先完成，peer half-close 后半截下一请求头随后作为 follow-up malformed request 返回 `400`；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive `Content-Length` partial follow-up headers bridge proof：首个请求的 `200 / echo:5` 会先正常返回，后续把半截下一请求头补全后，第二个 request 仍可继续合法返回 `200 / ok`；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive chunked garbage tail safe-handling proof：首个请求先完成，尾巴随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive chunked partial follow-up request-line safe-handling proof：首个请求先完成，半截下一请求行随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive chunked partial follow-up request-line bridge proof：首个请求的 `200` 会先正常返回，后续若把半截下一请求行补全，第二个请求也会继续合法完成；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive chunked truncated follow-up headers safe-handling proof：首个请求先完成，peer half-close 后半截下一请求头随后作为 follow-up malformed request 返回 `400`；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive chunked partial follow-up headers bridge proof：首个请求的 `200 / echo:5` 会先正常返回，后续把半截下一请求头补全后，第二个 request 仍可继续合法返回 `200 / ok`；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive chunked trailer-complete garbage tail / truncated follow-up request-line / truncated follow-up headers safe-handling proof：完整 trailer section 结束后首个请求仍先完成，尾巴随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive chunked trailer-complete partial follow-up request-line bridge proof：首个 trailer-complete chunked request 的 `200 / echo:5` 会先正常返回，后续把半截下一请求行补全后，第二个 request 仍可继续合法返回 `200 / ok`；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive chunked trailer-complete partial follow-up headers bridge proof：首个 trailer-complete chunked request 的 `200 / upload:hello` 会先正常返回，后续把半截下一请求头补全后，第二个 request 仍可继续合法返回 `200 / next`，且首请求的 trailer declaration / trailer isolation 契约保持不变；Linux `epoll` backend 现在也有相同 raw-wire live proof。
- `test_http_security` 现在也有 keep-alive chunked trailer-complete same-write pipelining raw-wire proof：首个 trailer-complete chunked request 与同包第二个 request 都会稳定返回各自的 `200` 响应，首请求 body 仍保持 `echo:5`；Linux `epoll` backend 现在也有相同 live proof。
- `TChunkedWriter` 现在有独立 focused 覆盖，并且 helper 自身会在 terminal chunk 后拒绝继续写入。
- `WebSocket` 现在也有 upgrade read-ahead focused 覆盖：握手请求和首帧同包写入时，hijack 后依然能正确读到首帧。
- facade 覆盖现在除了 `test_http_contract` / `test_http_smoke`，也直接来自 `test_http_static` / `test_http_websocket`；static / websocket helper 边界已收口到 facade。

## Public Surface Matrix

| Surface                                        | Public contracts                                                                                                                                                                   | Coverage              | Evidence                                                                          | Next action                                                                                                               |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `nextpas.core.http` facade                     | type aliases, status constants, factory/forwarding functions; direct proof now includes facade consumption of `HTTP_STATUS_SWITCHING_PROTOCOLS` / `HTTP_STATUS_EARLY_HINTS` / `HTTP_STATUS_SEE_OTHER` / `HTTP_STATUS_PAYLOAD_TOO_LARGE` / `HTTP_STATUS_NOT_IMPLEMENTED` / `HTTP_STATUS_HEADER_TOO_LARGE` with correct status-text mapping, facade forwarding for status-class helpers, query helpers, `TStringArray`, `MiddlewareFunc` / `TMiddlewareWrapFunc`, `TCorsOptions` / `CorsMiddleware`, `RecoveryMiddleware`, `ServeFile` / `ServeDir` / `UpgradeWebSocket`, `SetBasicAuth` / `SetBearerAuth`, `HttpGetToWriter`, `HttpWriteResponseString`, `IWebSocket`, `TWebSocketOpcode`, and `TWebSocketFrame` / `wsOp*` enum values, plus future default registry consumer proof via `NewHttpClient(Options)` -> custom `hvHttp2` transport and `NewHttpServer(Handler, Options)` -> custom `hvHttp3` transport | focused + integration | `test_http_contract`, `test_http_smoke`, `test_http_static`, `test_http_websocket`, `test_http_client` | Revisit later whether selected concrete implementation types should also enter the facade, or remain unit-local by design. |
| `http.base`                                    | `THttpVersion`, `THttpMethod`, `THttpStatus`, `EHttpError` message preservation + `ecNetwork` category, status text plus status-class helpers for `1xx` / `2xx` / `3xx` / `4xx` / `5xx`, `TUrl.Parse` including invalid explicit authority-port fail-fast, `TUrl.HostPort` IPv6 bracket authority formatting, `TUrl.ParseRequestTarget` origin-form / path-only / absolute-form / asterisk-form / authority-form / scheme-like origin-form / empty-input behavior, `THttpClientOptions.Default`, `THttpServerOptions.Default`, `TTcpServerBackend` / backend constants re-export, `HTTP_STATUS_CONTINUE` / `HTTP_STATUS_EARLY_HINTS` / `HTTP_STATUS_NOT_IMPLEMENTED` text mapping | focused               | `test_http_base`, `test_http_contract`                                            | None in this phase.                                                                                                       |
| `IHttpHeaders` / `THttpHeaders`                | `SetHeader`/add/get/getall/has/remove/clear/count/foreach/clone, validation, Clear 后可复用且不会暴露 stale entries, common `Authorization` helpers (`SetBasicAuth` / `SetBearerAuth`) with nil-header rejection and replacement semantics, concrete parser-trusted `AddParsed` / `AddParsedSpans` canonical lowercase insertion, header lookup hot-helper inline source contract (`FindFirst` / `NeedsNormalize` / `NormalizeIfNeeded`) | focused               | `test_http_headers`, `test_http_contract`, `test_http_integration`, `test_http_benchmarks` | Prefer public `SetHeader` / `Add` validation for external input; use concrete trusted helpers only with parser-validated headers/spans.               |
| URL utilities                                  | encode/decode/query parse/query encode/value/has, including facade forwarding for query value/has helpers                                                                          | focused               | `test_http_url`, `test_http_contract`                                             | None in this phase.                                                                                                       |
| `IHttpRequest` / `THttpRequest`                | method/url/direct path/direct raw-query/version/headers/body/content-length/remote/path/query params; factory helpers cover simple requests, custom headers/body/content-length, URL string overloads, copied Pascal string body overloads, and copied `TBytes` body overloads; direct proof includes default empty `RemoteAddr` plus `SetRemoteAddr` -> interface getter round-trip, lazy request-target construction still materializes `Url` correctly on demand, and `Path` / `RawQuery` / `QueryParam` now use lightweight request-target projection for origin-form and related target forms without forcing full URL materialization | focused + integration | `test_http_message`, `test_http_contract`, `test_http_server`, `test_http_integration`, `test_http_benchmarks` | Prefer `Req.Path` / `Req.RawQuery` in handler/router hot paths; keep `Req.Url` for callers that need the full URL record. |
| `IHttpResponse` / `THttpResponse`              | status/headers/body, nil-header normalization, fixed string/`TBytes` response helper overloads with copied body, generated `Content-Length`, nil-body compatibility, and fixed-body header conflict rejection | focused               | `test_http_message`, `test_http_contract`                                         | Keep higher-level JSON/error/redirect response helper families deferred until content-type, encoding, and ownership contracts are explicit. |
| `IHttpResponseWriter` / `TH1ResponseWriter`    | write status, headers, body, flush, chunked default, explicit no-body status (`100` / `101` direct proof plus shared `1xx/204/304` predicate) does not auto-inject chunked framing and strips preset chunked `Transfer-Encoding` before no-body / informational wire output, non-`101` informational responses such as `103 Early Hints` do not commit the final response and allow a later final `200` + body, `101` body writes are rejected without leaking bytes, HEAD-style suppress-body mode discards body output, short-write writer path retries to full framing/body or raises on zero progress, no implicit close, common status-line fast path with unknown-status fallback preserved, compact small header-block write path preserves exact wire bytes and falls back before writing partial bytes for large blocks, `HttpWriteResponseString` fixed string helper with nil-writer rejection, informational-status rejection, no-body status pre-commit rejection, empty `204/304` entity-header suppression, body-permitted content-type/content-length publication, exact wire proof, short-progress retry, zero-progress `EIOError`, and facade visibility, benchmark smoke for fixed `200 OK` header-only serialization, 6-header block serialization, common error status-line serialization, and fixed `200 OK` + 13B body serialization | focused + integration | `test_http_h1writer`, `test_http_integration`, `test_http_server`, `test_http_contract`, `test_http_benchmarks` | Keep `101` as the upgrade/switching boundary; do not add broad response helper families until content-type, encoding, error body, and redirect ownership contracts are explicit. |
| `IHttpHandler` / `HandlerFunc`                 | handler wrapping and serving; nil closure / method / procedure callbacks are rejected early with `EHttpError`                                                                       | focused               | `test_http_middleware`, `test_http_contract`                                      | None in this phase.                                                                                                       |
| `IHttpMiddleware` / `Chain` / `MiddlewareFunc` | wrapping, order, short-circuit, response mutation, CORS preflight/header helper, recovery helper; facade forwarding for `MiddlewareFunc` / `TMiddlewareWrapFunc`, `CorsMiddleware` / `TCorsOptions`, and `RecoveryMiddleware`; nil middleware callback / nil chain root handler / nil middleware entry are rejected early with `EHttpError`, and `Chain` releases the partially constructed chain when later assembly fails | focused               | `test_http_middleware`, `test_http_middlewares`, `test_http_integration`, `test_http_contract` | None in this phase.                                                                                                       |
| `IHttpRouter` / `THttpRouter`                  | handle/use/get/head/post/put/delete/patch/options/connect/trace/serve, params, wildcard, method dispatch, 404/405, HEAD fallback to GET route with request method preserved, explicit HEAD route wins, 405 Allow includes implicit HEAD, benchmark smoke for static-route `ServeHTTP` handler dispatch | focused + integration | `test_http_router`, `test_http_contract`, `test_http_integration`, `test_http_benchmarks` | None in this phase.                                                                                                       |
| `IHttpServer` / `THttpServer`                  | listen/shutdown/local addr/is-running lifecycle shape, fail-fast nil-handler rejection, explicit runtime backend selection forwarding into `nextpas.core.net.server`, limits, keep-alive, request body, fixed-length `MaxBodySize` explicit `413` rejection with no handler entry on both threaded and Linux `epoll` backends, `Expect` request-side contract (`100-continue` body-bearing requests emit one interim `100 Continue`; the positive fixed-length flow now also has direct raw-wire proof in `test_http_security`: interim `100` arrives first, the handler is not entered before body arrival, and final `200` only arrives after the body is sent; chunked ingress now likewise has direct raw-wire security proof for both the positive path and the after-interim limit path: `Expect + Transfer-Encoding: chunked` sends interim `100 Continue`, the handler is not entered before chunked body arrival, final `200` only arrives after the decoded body is sent, and cross-chunk `MaxBodySize` overflow after the interim response still ends in final `413` without handler entry; if interim `100` has already been sent and the peer then sends an invalid chunk-size, focused security/server proof now directly locks final `400`, no repeated interim `100`, no accidental `200`, and no handler entry; if interim `100` has already been sent and the peer then sends a malformed chunk extension or omits the chunk-data CRLF, focused security/server proof now likewise directly locks final `400`, no repeated interim `100`, no accidental `200`, and no handler entry; if interim `100` has already been sent and the peer then sends a malformed trailer field, a truncated trailer field-name EOF, a truncated trailer separator EOF, a truncated trailer empty-value CR EOF, a truncated trailer empty-value EOF, a truncated trailer empty-value section CR EOF, a truncated trailer whitespace CR EOF, a truncated trailer whitespace EOF, a truncated trailer whitespace section EOF, a truncated trailer whitespace section CR EOF, a truncated trailer field line EOF, a truncated trailer field CR EOF, a truncated trailer section EOF, a truncated trailer section CR EOF, or an oversize trailer, focused security/server proof now likewise directly locks final `400/400/400/400/400/400/400/400/400/400/400/400/400/400/431`, no repeated interim `100`, no accidental `200`, and no handler entry; if interim `100` has already been sent and the body then stalls mid-request, or never makes any post-interim progress at all, both threaded and Linux `epoll` live paths now directly prove request-side `IdleTimeout` safe-close with no appended final status-line and no synthetic `500`, and `test_http_server` now directly locks the same fixed-length / chunked partial-stall + zero-progress truth as a public-contract proof; `Content-Length: 0 + Expect: 100-continue` now also has direct live proof that no interim `100 Continue` is emitted when the request does not actually declare a body, the same no-interim behavior is directly locked for a normal request that omits both `Content-Length` and `Transfer-Encoding`, a no-length `HEAD + Expect: 100-continue` request likewise skips interim `100` while preserving the HEAD bodyless wire contract, and `Expect + Transfer-Encoding: gzip, chunked` / `Expect + Transfer-Encoding: chunked, gzip` now directly lock the error-first rule: final `501` / `400` is returned without interim `100`; comma-separated `Expect` values that contain `100-continue`, including duplicate-member forms, still emit the same interim `100 Continue`; repeated `Expect` header-lines are aggregated across all values, so later unsupported members still short-circuits to final `417` without interim `100` or handler entry；declared oversize `Content-Length` under `Expect` short-circuits to final `413`), chunked request decode, malformed chunk rejection, unsupported request transfer-coding explicit `501` rejection with `chunked`-not-final malformed `400` preserved, response-side `204/304` no-body wire contract (`no transfer-encoding: chunked`, no forced `content-length`, no chunk trailer), HEAD response-body suppression (`no transfer-encoding: chunked`, no chunk trailer, no body bytes even if handler writes, explicit `Content-Length` preserved when supplied), committed response exception safe-close contract (once response is flushed/committed, later handler exception must not append synthetic `500`), zero-progress response write failure safe-stop contract (first response write failure stops the session and prevents later pipelined requests from being consumed), request-side poll-driven `IdleTimeout` parity contract (session 在第一个 request byte 到达前就会 arm read-side `WakeDeadline`；partial fixed-length body stall、partial chunk-size-line stall 与 partial chunked trailer stall 继续沿用同一个 request-parse deadline，不会因为已有部分 progress 就偷偷 re-arm；超时后安全关闭，并把 `WakeDeadline` 清回 infinite), write-timeout safe-close contract (`WriteTimeout > 0` arms a write deadline at real socket drain time, and the same timeout budget also applies to direct parser-error / size-limit / fail-fast error responses; whole-run direct `400/413/431/417/501` rejection paths are all directly locked to arm that deadline before attempting the error response, and both pre-first-byte timeout plus partial-error-response timeout preserve the original error status line without appending synthetic `500` or a second status line; poll-driven standalone direct `400/413/431/417/501` timed drains likewise preserve the original status line under partial-write timeout and clear `WakeDeadline` back to infinite on timeout close; partial-write timeout stops the session before later pipelined requests are consumed; partial timed drain only re-arms the deadline when new bytes are written, not on pure would-block or deadline-close, and timeout-close clears `WakeDeadline` back to infinite), slow buffered handler contract (threaded and Linux `epoll` backends both allow pre-drain in-memory response production to exceed `WriteTimeout` without misclassifying it as a socket write-timeout; the timeout budget begins when drain to the peer actually starts), refined real-socket stalled-peer proof with threaded/Linux `epoll` parity (connection eventually closes under backpressure without later pipelined request consumption, without synthetic `500`, without malformed follow-up `400`, without unsupported transfer-coding follow-up `501`, and without a second status line on wire; large response handler-side production may already be fully complete before close, close observation window is intentionally relaxed and not frozen as a strict `WriteTimeout` SLA), untimed poll-path bounded response queue contract (active drain + 1 queued response, one buffered follow-up request may complete behind an earlier undrained response, queued follow-up `400`/`413`/`431`/`417`/`501` are directly locked to preserve wire order behind the earlier response, close-after-drain queued errors do not wait an extra writable wake just because malformed tail bytes remain buffered, and queued follow-up `400/413/431/417/501` already have Linux `threaded/epoll` real-socket/backpressure wire-order proof), generic malformed request explicit `400` rejection, `HTTP/1.1 missing Host` explicit `400` rejection with `HTTP/1.0` compatibility preserved, `HTTP/0.9 / no-version` explicit `400` rejection, `CRLF injection / request-line splitting` explicit `400` rejection, `negative Content-Length` explicit `400` rejection, `very long method` explicit `400` rejection, header field over `MaxHeaderSize` explicit `431` rejection, request-target over `MaxHeaderSize` explicit `431` rejection, `Content-Length + Connection: close + extra bytes after body` explicit `400` rejection, `chunked + Connection: close + extra bytes after terminal chunk` explicit `400` rejection, same-write pipelined request isolation for fixed-length and chunked first requests, intentional keep-alive request-tail transport policy: fixed-length / plain chunked / trailer-complete chunked requests always complete once the current request framing is complete, unread tail bytes stay buffered for the next request, partial follow-up request-line bytes and partial follow-up headers may later complete into a valid second request, and malformed follow-up requests become follow-up `400` only after they are conclusively malformed or EOF-truncated, CL+TE conflict rejection, duplicate `Content-Length` explicit `400` rejection, `null-byte header` rejection, malformed chunk extension explicit `400` rejection, missing chunk-data CRLF explicit `400` rejection, terminal chunk ending CR EOF truncation explicit `400` rejection, terminal chunk extension EOF truncation explicit `400` rejection, terminal chunk ending after extension EOF truncation explicit `400` rejection, terminal chunk ending after extension CR EOF truncation explicit `400` rejection, truncated trailer field-name EOF truncation explicit `400` rejection, truncated trailer separator EOF truncation explicit `400` rejection, truncated trailer empty-value CR EOF truncation explicit `400` rejection, truncated trailer empty-value EOF truncation explicit `400` rejection, truncated trailer empty-value section CR EOF truncation explicit `400` rejection, truncated trailer whitespace EOF truncation explicit `400` rejection, truncated trailer whitespace CR EOF truncation explicit `400` rejection, truncated trailer whitespace section EOF truncation explicit `400` rejection, truncated trailer whitespace section CR EOF truncation explicit `400` rejection, truncated trailer field line EOF truncation explicit `400` rejection, truncated trailer field CR EOF truncation explicit `400` rejection, truncated trailer section CR EOF truncation explicit `400` rejection, chunk-extension line EOF truncation explicit `400` rejection, chunk-size line EOF truncation explicit `400` rejection, chunk-data CRLF EOF truncation explicit `400` rejection, terminal 0 chunk ending EOF truncation explicit `400` rejection, chunked trailer isolation, oversize trailer `431` rejection before handler dispatch, malformed trailer explicit `400` rejection before handler dispatch, fixed-length request body EOF truncation explicit `400`, chunked `MaxBodySize` immediate `413` once ingress crosses the limit, request-line/header EOF truncation explicit `400`, queued follow-up payload-too-large `413` wire-order preservation after a prior response body, queued follow-up unsupported transfer-coding `501` wire-order preservation after a prior response body, queued follow-up unsupported `Expect` `417` wire-order preservation after a prior response body, queued follow-up header-too-large `431` wire-order preservation after a prior response body, remote addr, explicit transport injection, registry-backed default resolution, `bench_http_server` small-run benchmark smoke with normalized `operation/impl/iterations/ns/op/req/s` output plus Go/Rust comparator smoke | focused + integration | `test_http_server`, `test_http_smoke`, `test_http_contract`, `test_http_registry`, `test_http_security`, `test_http_base`, `test_http_benchmarks` | Keep ownership/limit coverage tight as H1 behavior evolves; next push should prioritize formal benchmark runner/results or still-unclassified request-side runtime gaps, not broad parity cloning. |
| `IHttpClient` / `THttpClient`                  | Send/Get/Post/Put/Delete/Patch/Head, `CloseIdleConnections` lifecycle seam with optional transport capability dispatch and H1 idle pool clear semantics, `Post` / `Put` / `Patch` shortcut body materialization through a shared bytes-buffer helper, close-capable request body release after `Send` success/failure and after reader-shortcut buffering, GET-style redirect discarded-body release before follow-up with exactly-once close, direct `string` / `TBytes` shortcut body overloads with forwarded `content-type` and generated `content-length`, headers-level Basic/Bearer auth helper values are forwarded by `Send`, explicit `Send(nil)` `EArgumentError` rejection, stale pooled keep-alive retry narrowed to retry-safe plus replayable-body requests with non-idempotent or non-replayable fail-fast semantics, redirects including `301` / `302` / `303` replay-as-GET body drop, `307` / `308` method preservation with seekable body rewind/replay and non-replayable non-empty body fail-fast, redirect follow-up caller header preservation with cross-authority sensitive-header stripping and same-authority/custom `Host` preservation including omitted-port vs. default-port authority equivalence, relative `Location` path/query/fragment parsing, absolute `http` / `https` scheme case-insensitive matching with unsupported absolute scheme and malformed bracketed IPv6 authority fail-fast, path-relative `Location` base-directory merge plus dot-segment normalization, fragment-only `Location` path/query preservation, and network-path `Location` scheme inheritance plus authority/path/query parsing before follow-up transport dispatch, direct URL invalid-port fail-fast before transport dispatch, timeout, negative `THttpClientOptions` validation, host header, pooling, chunked/EOF/truncated body handling, HEAD response header preservation with body suppression under explicit `Content-Length`, `HttpGetToWriter` / `HttpGetToFile` successful body copy, response body release on success/failure/non-2xx discard paths, non-2xx rejection, atomic final-file publish, and truncated-body temp cleanup, `HttpReadResponseBodyString` / `HttpReadResponseBodyBytes` full-body helpers with nil-body / nil-response boundaries, explicit transport injection that preserves custom schemes, default H1 direct-request scheme validation (`http` / empty only), registry-backed default resolution | focused               | `test_http_client`, `test_http_smoke`, `test_http_contract`, `test_http_registry`, `test_http_examples` | Consider adding a same-client follow-up regression if later transport refactors reopen pooling behavior.                  |
| `IHttpTransport`                               | `RoundTrip`, facade client injection, constructor default resolution, future-version custom registration seam via `hvHttp2` mock default-constructor proof                                                              | focused               | `test_http_contract`, `test_http_registry`                                        | Keep registration internal until real H2/H3 transports exist; widen to public API only if there is a clear external need. |
| `IHttpServerTransport`                         | `ServeConn` ownership return, facade server injection, constructor default resolution, future-version custom registration seam via `hvHttp3` mock default-constructor proof                                           | focused               | `test_http_contract`, `test_http_registry`                                        | Keep registration internal until real H2/H3 transports exist; add protocol-family coverage when new server transports land. |
| `IHttpServerSessionFactory` / `IHttpServerSessionFactoryWithContext` | transport-side session creation, legacy factory fallback, context-aware factory preference, foundation `WorkerHandoff` propagation into HTTP transport, context-aware H1 session exposes `ITcpServerPollDrivenSession`, reactor-owned read/parse can hand off one completed request at a time instead of whole-connection `Run`, poll-driven initial read-wait now arms a finite read-side `WakeDeadline` before the first request byte arrives and timeout-close clears it back to infinite, partial fixed-length body stall, partial chunk-size-line stall, and partial chunked trailer stall now also have focused request-side timeout proof, and partial request progress does not re-arm the read deadline, worker result is now applied on completion instead of mutating reactor-owned response state directly, successful responses drain via completion wake + `peWritable` instead of worker-owned sync socket writes, stalled timed drain closes via `WakeDeadline`, successful timed drain clears `WakeDeadline` back to infinite after the response is fully drained, stalled/partial timed drain timeout-close likewise clears `WakeDeadline` back to infinite, partial-write timed drain only re-arms `WakeDeadline` after real write progress and still does not hand off buffered follow-up requests before deadline close, and untimed poll path now has active+1 queued ordered response proof plus direct queued follow-up `400/413/431/417/501` wire-order coverage; standalone direct `400/413/431/417/501` likewise enters reactor-owned writable drain instead of falling back to sync socket writes | focused               | `test_http_contract`, `test_http_server`                                          | Next step is to return to malformed-framing security proof or request-side live-socket timeout characterization, not to keep widening synthetic-only timeout coverage for its own sake. |
| `IHttpHijacker` / `TH1ResponseWriter.Hijack`   | facade alias, connection takeover, server ownership transfer, exception-after-hijack ownership preservation, websocket upgrade path keeps handler-owned websocket alive and avoids synthetic `500` after post-upgrade handler exception | focused + integration | `test_http_contract`, `test_http_h1writer`, `test_http_server`, `test_http_websocket` | Keep websocket upgrade ownership coverage in sync if upgrade lifecycle semantics widen later.                             |
| Static serving                                 | `ServeFile`, `ServeDir`, facade forwarding, MIME inference with case-insensitive extension matching and `application/octet-stream` fallback for unknown extensions                 | focused               | `test_http_static`                                                                | Add streaming / range / binary-file contract later if static serving graduates beyond simple helper scope.                |
| WebSocket                                      | upgrade, frame read/write, ping/pong/close, coalesced first-frame after hijack, post-upgrade exception still preserves handler-owned websocket ownership and frame I/O, facade forwarding for helper/types/opcodes/options/default-size constants, unmasked client frame protocol-error rejection, RSV bit protocol-error rejection, control-frame payload length > 125 protocol-error rejection, reserved opcode protocol-error rejection, fragmented control-frame protocol-error rejection, invalid close code protocol-error rejection, invalid UTF-8 text frame rejection, invalid UTF-8 close reason rejection, standalone continuation frame rejection, valid fragmented UTF-8 text sequence acceptance, 16-bit non-canonical payload length rejection, 64-bit non-canonical payload length rejection, 64-bit payload length high-bit rejection, `MaxFrameSize` declared-length fail-fast rejection, `MaxMessageSize` fragmented-message cumulative rejection, outgoing `WriteText` invalid UTF-8 rejection before write, outgoing `Ping` / `Close` oversize control payload rejection before write, outgoing `Close` invalid code / invalid UTF-8 reason rejection before write, runnable `http_websocket_echo_demo` build/start/handshake/text-echo smoke | focused               | `test_http_websocket`, `test_http_examples`                                      | Continue WebSocket negative coverage only when it exposes a new behavior gap; otherwise return to HttpServer runtime gaps or benchmark planning. |
| H1 parser                                      | request/response parser API, response keep-alive inference, truncated fixed-length EOF rejection, `HEAD`-style skip-body response completion under explicit `Content-Length`, chunked request decode/error/truncation, unsupported request transfer-coding rejection before successful chunked decode, `chunked`-must-be-final transfer-coding rejection, request fixed-length body EOF truncation, request-line/header EOF truncation, malformed chunk extension rejection, missing chunk-data CRLF rejection, terminal chunk ending CR EOF truncation rejection, terminal chunk extension EOF truncation rejection, terminal chunk ending after extension EOF truncation rejection, terminal chunk ending after extension CR EOF truncation rejection, truncated trailer field-name EOF truncation rejection, truncated trailer separator EOF truncation rejection, truncated trailer empty-value CR EOF truncation rejection, truncated trailer empty-value EOF truncation rejection, truncated trailer empty-value section CR EOF truncation rejection, truncated trailer whitespace EOF truncation rejection, truncated trailer whitespace CR EOF truncation rejection, truncated trailer whitespace section EOF truncation rejection, truncated trailer whitespace section CR EOF truncation rejection, truncated trailer field line EOF truncation rejection, truncated trailer field CR EOF truncation rejection, truncated trailer section CR EOF truncation rejection, chunk-extension line EOF truncation rejection, chunk-size line EOF truncation rejection, chunk-data CRLF EOF truncation rejection, terminal 0 chunk ending EOF truncation rejection, generic malformed request rejection, `HTTP/0.9 / no-version` rejection, `CRLF injection / request-line splitting` rejection, `negative Content-Length` rejection, `very long method` rejection, `Content-Length + Connection: close + extra bytes after body` rejection, intentional keep-alive request-tail isolation: current request completes first, tail bytes are left for the next parse pass, partial follow-up bytes may later complete into a valid second request, conclusively malformed or EOF-truncated follow-up requests reject on the follow-up parse only, `chunked + Connection: close + extra bytes after terminal chunk` rejection, trailer isolation from ordinary headers, late trailer byte accounting, malformed trailer rejection, `CL+TE` conflict rejection, duplicate `Content-Length` rejection, adapter/header-complete framing rejection consumes through offending headers without publishing request state, `null-byte header` rejection, same-read pipelined request isolation for fixed-length and chunked first requests | focused               | `test_http_h1parser`, `test_http_server`, `test_http_security`                    | Continue malformed-framing audit only where still-unclassified terminal/trailer grammar remains, and revisit transport policy only if buffering semantics intentionally change. |
| H1 scan                                        | CRLF/double CRLF/colon/token scan                                                                                                                                                  | focused               | `test_http_h1scan`                                                                | Benchmark after correctness phase.                                                                                        |
| H1 fast parser                                 | fast request parse result                                                                                                                                                          | focused               | `test_http_h1fast`                                                                | Keep differential tests against llhttp.                                                                                   |
| H1 outbound buffer                             | in-memory response buffering, full drain through `IWriter`, resumable nonblocking `TryDrainTo`, benchmark smoke for 1 KiB write + in-memory drain                                | focused               | `test_http_h1writer`, `test_http_server`, `test_http_benchmarks`                  | Add real-socket drain benchmark only when it can avoid scheduler-noise-heavy conclusions.                                  |
| H1 chunked writer                              | chunk framing, hex length, zero-length write, terminal chunk, write-after-final, short-write retry to complete framing/body, zero-progress write failure                           | focused               | `test_http_h1chunked`, `test_http_h1writer`, `test_http_server`                   | Add malformed chunk parser coverage in parser/security suites rather than expanding writer helper scope.                  |

## Highest-Priority Remaining Work

1. runtime/socket overhead 仍需继续做 isolate-first characterization。parser、
   lazy-header、writer、outbound 与 full-chain benchmark 面已存在，下一批更值得做
   的是真实 remaining runtime cost，而不是过早追加最终排名表。
2. client ergonomics 只在出现真实缺口时继续扩面。当前 request construction、
   response read/release、redirect / timeout fail-fast 语义已足够强；后续若要引入
   builder、per-request policy 或更高层 body helper，必须先把稳定 contract 写清楚。
3. static / WebSocket / H2-H3 继续维持清晰边界：static 与 WebSocket 仍停在
   helper-level public surface，H2/H3 仍只推进 registry / transport seam。后续
   不再靠机械 negative-case 复制制造“进展”，而只补真实行为缺口或 future seam 风险。
