# nextpas.core.http

HTTP module providing server and client capabilities with radix-tree routing,
middleware chaining, and a centralized internal transport registry.

## Module Docs

| Doc | Role |
|-----|------|
| **[`ROADMAP.md`](ROADMAP.md)** | **Sole forward NEXT** — Eras/Waves, Goal Loop, Inbox |
| [`CLAIM.md`](CLAIM.md) | **What we claim** — allow/deny + p99 conditions (R1 + HS freeze) |
| [`REPRO.md`](REPRO.md) | 1h release-evidence playbook |
| [`GOAL_TREE.md`](GOAL_TREE.md) | North star + do-not-drift only (no live Wave name) |
| [`CONTRACT.md`](CONTRACT.md) | Public behavior contract |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Stable architecture facts, runtime ownership, protocol seams |
| [`API_COVERAGE.md`](API_COVERAGE.md) | Public API evidence matrix |
| [`BENCHMARKS.md`](BENCHMARKS.md) | Benchmark truth and comparator caveats |
| [`archive/`](archive/README.md) | Historical waves only — **not** a backlog |

## Production checklist（PD-0 / PD-1B）

复制粘贴生产服务时按此表：

| 项 | 做 | 别做 |
|----|----|------|
| Server options | `THttpServerOptions.Production`（或 Default，PD-1B 后 RW 同为 30s） | 长轮询/SSE 忘了 `WithReadTimeout(0)` 导致 30s 断流 |
| Server 工厂 | `NewHttpServer(handler, Production…)`；arena 便利工厂已走 Production | 用 IdleTimeout **alone** 当完整模板 |
| Client options | `Default.Timeout=30000` 或 `WithTimeout`；池淘汰见 IdleTTL | 只挂 cancel、不设 Timeout 当唯一模板 |
| Idle 对照 | server IdleTimeout（默认 30s）≠ client IdleTTL（默认 90s） | 把两个旋钮当成同一个 |
| Keep-alive | 默认开（INV-1）；长连接写失败见 CONTRACT §4.4 | 大 body / 背压缺口已有 Q1-4 + 413 矩阵，勿空写 KPI |
| TLS | `TLSContext` + H1/H2 产品路径（C-A / H2P-3） | 空 facade / 假 H3 |
| 宣称 | 只说 [`CLAIM.md`](CLAIM.md) 允许句 | Windows scale / 跨机榜 / H1÷H2 RPS package KPI |
| Body 读入内存 | `HttpReadRequestBody*` 默认 4 MiB；更大用 `BytesMax` / `BodyCacheMiddlewareWith` | 依赖旧无界默认；BodyCache 不设 max |
| 请求解压 | `DecompressMiddleware` 默认 4 MiB 解压输出上限 | `DecompressMiddleware(0)` 当生产默认 |
| Deadline | **默认不装**；短 JSON 才考虑；知悉非抢占 + 全缓冲 | 当 Go `context.WithTimeout`；大 body 不设缓冲上限 |
| ResponseTime | 仅写 `X-Response-Time`（`middleware.responsetime`） | 当成限时中间件；限时用 server RW timeout / Deadline |

细节权威：[`CONTRACT.md`](CONTRACT.md) §2.2 Default vs Production + IdleTimeout vs IdleTTL。

## Architecture

```
Facade:
  nextpas.core.http              — full surface (stable umbrella; >800 行纯聚合，认知负荷已按子facade分流)
  nextpas.core.http.minimal      — thin surface (types + router + server/client + chain, ~201 行)
  nextpas.core.http.messages     — messages facade (request/response + writers + redirects + errors + body readers, ~420 行)
  nextpas.core.http.transports   — transports facade (server/client factories + fetch helpers + TCP backend, ~520 行)
  nextpas.core.http.extensions   — extensions facade (static/websocket/sse/stream/cookie/form + headers/url + ETag, ~520 行)
  nextpas.core.http.middlewares  — middlewares facade (middleware family, ~500 行)
  Application layer: Request, Response, Headers, Router, Middleware
  Internal registry: default version -> transport factory
  Protocol layer: impl.h1 (landed), impl.h2 transport (landed), impl.h3 (blocked on QUIC)
```

| uses | 内容 |
|------|------|
| `nextpas.core.http.minimal` | base/intf/headers/url/router/message + server/client + HandlerFunc/Chain |
| `nextpas.core.http.messages` | message 域：request/response 建造与写入/重定向/RFC7807/有界读入 |
| `nextpas.core.http.transports` | transport 域：server/client 工厂与 Get/Post/ensure/decode/fetch 族 + TCP backend |
| `nextpas.core.http.extensions` | extension 域：static/websocket/sse/stream/cookie/form + headers/url + ETag/条件请求 |
| `nextpas.core.http.middlewares` | middleware 域：cors/recovery/logger/… 全家桶（零拷贝/`bytes.ops` 单源） |
| `nextpas.core.http` | 上表全部聚合（五facade + middleware 全家桶）；>800 行纯聚合 umbrella 仍稳定，仅认知负荷已分流 |

Current built-in mapping is `hvHttp10` / `hvHttp11` -> H1, with `hvHttp11`
as the default client/server version.

## Public Surface Map (by scenario)

默认 `uses nextpas.core.http`；只要服务/路由/客户端可用 `uses nextpas.core.http.minimal`：

| Scenario | Start here |
| --- | --- |
| Client GET/POST JSON | raw: `PostJson` → `IHttpResponse` (`FinalUrl` / `Version` metadata); ensure string: `HttpPostJson` / `GetString`; ensure+decode: `HttpGetJson` / `HttpPostJsonDocument` / `GetJson` / `HttpReadResponseJson` |
| Fluent request | `THttpRequestBuilder` → `Send` |
| Streaming / chunked body | `SendStreaming` / builder `Body(IReader)` (H1 chunked if CL omitted) |
| Auth / retry / jar / proxy / TLS | `WithBearerAuth`, `WithRetry` (delta + HTTP-date Retry-After), `WithCookieJar`, `WithProxyUrl` (`http://user:pass@proxy` → **Basic only**), `WithTLSContext` |
| Direct HTTPS client | `NewHttpClient` + `WithTLSContext` / options `TLSContext` → `Get('https://…')` (H1 TLS wrap；pool reuse after RH-1) |
| HTTPS **server** | `THttpServerOptions.TLSContext` → H1: `NewH1TlsServerTransport`（ALPN `http/1.1`）；H2: `NewH2TlsServerTransport`（ALPN `h2`） |
| Cancel / timeout | `NewHttpCancelToken`, builder `CancelToken`, `WithTimeout`, `WithConnectTimeout` / options `ConnectTimeout` |
| Multipart upload | `PostMultipart` or `EncodeMultipartFormData` + `Post` |
| Server | `NewRouter` → `NewHttpServer` → `ListenAndServe` |
| Middleware | `CorsMiddleware`, `RecoveryMiddleware`, `Chain`, … |
| WebSocket | `UpgradeWebSocket` / `ConnectWebSocket` + `TWebSocketOptions.ConnectTimeout`/`Timeout` (Default 30s) + optional `WithCancelToken` for mid-frame cancel |
| Static files | fs: `ServeFile` / `ServeDir`; virtual filesystem (IVfs): `ServeVfs` — ETag from backend ContentHash (`fnv-<8hex>`) with size+mtime fallback, unknown ModTime skips Last-Modified/IMS, dirs and invalid paths → 404; `HttpServeStaticStream` unified pipeline: conditional 304 (If-None-Match/If-Modified-Since), single Range 206/416 with `Accept-Ranges: bytes`, `If-Range` (ETag strong / HTTP-date) fallback to 200, `HEAD` header-only without opening stream, error paths HEAD-aware |
| Form parse | `ParseUrlEncodedForm` / `ParseMultipartFormData` |

## Quick Start

Run the examples instead of copy-pasting a partial snippet:

```sh
# from repo root (or any cwd that can reach core/)
make -C core/examples/nextpas.core.http/http_hello_server run
make -C core/examples/nextpas.core.http/http_get_client run
make -C core/examples/nextpas.core.http/http_server_options_demo run
make -C core/examples/nextpas.core.http/http_websocket_echo_demo run
```

- `http_hello_server` shows `NewRouter`, `Router.Get(...)`,
  `Req.PathParam`, `Req.QueryParam`,
  `NewHttpServer(..., THttpServerOptions.Production.WithRequestArena)`,
  and `ListenAndServe`.
- `http_get_client` shows `NewHttpClient`, `Client.Get(URL)`,
  `HttpReadResponseBodyString(Resp)`, and printing status / headers / body.
  Pass a URL as the first argument, or set `NEXTPAS_HTTP_GET_URL` when running
  it from a smoke harness that has selected a non-default port.
- `http_server_options_demo` shows `THttpServerOptions.Backend`,
  `WriteTimeout`, `MaxHeaderSize`, `MaxBodySize`, and a runnable `POST /echo`
  path where oversize request bodies are rejected before the handler.
- `http_websocket_echo_demo` shows `UpgradeWebSocket`, `IWebSocket.ReadFrame`,
  `WriteText`, and `Close` on a runnable `/ws` echo endpoint.
- The client defaults to `http://127.0.0.1:8080/hello/world?page=1` only when
  neither an argument nor `NEXTPAS_HTTP_GET_URL` is supplied.
- The server-options demo defaults to `threaded` on `127.0.0.1:8081`; pass
  `epoll` as the first arg on Linux to exercise the readiness backend.

## API Reference

### Status And Method Helpers

- `HttpMethodToStr` / `HttpStrToMethod` — convert between `THttpMethod` and
  wire method names.
- `HttpStatusText` — return the reason phrase for known status codes, or
  `Unknown` for unrecognized codes.
- `HttpStatusIsInformational` / `HttpStatusIsSuccess` /
  `HttpStatusIsRedirect` / `HttpStatusIsClientError` /
  `HttpStatusIsServerError` — classify status-code ranges without forcing
  callers to repeat magic `1xx` / `2xx` / `3xx` / `4xx` / `5xx` checks.

### Router

- `NewRouter` — create radix-tree router (implements IHttpRouter + IHttpHandler)
- `Handle(Method, Pattern, Handler)` — register route with path params (`:name`) and wildcards
- `Get/Head/Post/Put/Delete/Patch/Options/Connect/Trace(Pattern, Handler)` — public convenience methods on `IHttpRouter`
- `Use(Middleware)` — append middleware to the router chain

### Headers

- `NewHeaders` — create IHttpHeaders (case-insensitive, multi-value)
- `SetHeader/Add/Get/GetAll/Has/Remove/Count/ForEach/Clone`
- `SetBasicAuth(Headers, Username, Password)` / `SetBearerAuth(Headers, Token)`
  — set the `Authorization` header for common client request auth cases; nil
  headers raise `EHttpError(hekArgument)`, and existing authorization values are replaced.

### URL Utilities

- `TUrl.Parse` — parse full/relative URLs into scheme, userinfo, host, port, path, query, and fragment fields; invalid explicit authority ports raise `EHttpError`
- `TUrl.ParseRequestTarget` — parse HTTP request-target strings; origin-form skips authority parsing, absolute-form remains compatible with `TUrl.Parse`, and asterisk/authority-form targets are preserved as `Path`
- `UrlEncode/UrlDecode` — percent encoding
- `ParseQueryString/EncodeQueryString` — query parameter handling

### Middleware

- `HandlerFunc(Func)` — wrap closure as IHttpHandler
- `Chain(Handler, [Middlewares])` — compose middleware stack

### Messages

- **Recommended:** `THttpRequestBuilder.Create(Method, UrlString).Header(...).Body(...).Build`
  — fluent construction; covers auth, content-type, query, per-request options.
- **Public request factories (whitelist only):**
  - `NewRequest(Method, TUrl)` — minimal primitive factory
  - `NewRequest(Method, string)` — URL-parse bridge (no headers/body)
  - `NewGetRequest(Path)` — path-level GET helper
  - Prefer `THttpRequestBuilder` for headers/body/auth/options.
- `NewStreamingRequest` and multi-arg `NewRequest` overloads are **physically
  removed**. Use the builder or `IHttpClient.SendStreaming`.
- Builder note: `Body(IReader)` + `ContentLength(N)` for known length; missing
  length may use H1 chunked request body. Empty `Body('')` publishes
  `Content-Length: 0`.
- `NewResponse(Status, Headers, Body)` — build responses; nil headers create
  an empty header set so callers can safely read or mutate `Resp.Headers`.
- `NewResponse(Status, Headers, BodyText)` /
  `NewResponse(Status, Headers, BodyBytes)` — build fixed-body responses with
  a copied Pascal string or `TBytes` body and generated `Content-Length`.
  Caller-supplied headers are treated as response-owned; a matching
  `Content-Length` is accepted, conflicting values and `Transfer-Encoding` are
  rejected. `NewResponse(Status, Headers, nil)` stays source compatible with
  the nil-body form and does not publish `Content-Length`.
- `HttpWriteResponseString(Writer, Status, ContentType, Body)` — write a
  fixed Pascal string response through an `IHttpResponseWriter` and return the
  body bytes accepted by the writer. Nil writers raise `EHttpError(hekArgument)`;
  informational statuses raise `EHttpError` because the helper writes final
  responses; non-empty bodies for `204` / `304` raise before committing bytes;
  empty `204` / `304` responses skip entity headers; body-permitted final
  statuses publish a non-empty `Content-Type` and always set `Content-Length`.

### Server / Client (interfaces)

- `IHttpServer.ListenAndServe(Addr, Port)` / `Shutdown` / `LocalAddr` / `IsRunning`
- `IHttpClient.Send(Req)` / `CloseIdleConnections` / `Get(Url)` /
  `Post(Url, ContentType, Body)` / `Put` / `Delete` / `Patch` / `Head`;
  `Send(nil)` raises `EHttpError(hekArgument)`
- `Post` / `Put` / `Patch` / `Delete` body shortcuts accept Pascal `string` and
  `TBytes` only (publish `Content-Length`). Non-empty caller `Content-Type` is
  forwarded; empty content type omits the header. Stream bodies use
  `SendStreaming` or builder + `Send`.
- `WithRetry(N)` retries **429**, **5xx**, and **retryable transport errors**
  (`HttpErrorIsRetryable`: timeout/connect). Prefers delta-seconds
  `Retry-After` (cap 60s); otherwise exponential backoff (100ms base, max 5s).
  Other 4xx are not retried. Only **idempotent-safe** requests enter the loop:
  GET/HEAD/OPTIONS/TRACE or `Idempotency-Key` / `X-Idempotency-Key`
  (`HttpIsRetrySafeRequest`). Body is rewound via `IStream` when present.
- **Production client defaults**: `THttpClientOptions.Default.Timeout` is
  **30000** ms. Explicit `Timeout=0` still means unbounded post-dial IO
  (tests/special tools only). Prefer `WithTimeout` when overriding. Examples
  such as `http_get_client` use a finite timeout for this reason.
- **Production server defaults**: `THttpServerOptions.Default` Read/Write =
  **30000** ms (**PD-1B**). `Production` is the same RW named template — prefer
  it in product code for intent. Long-poll/SSE must set
  `WithReadTimeout(0)` / `WithWriteTimeout(0)` explicitly.
  IdleTimeout alone is not a full production template. Examples
  (`http_hello_server`, `http_websocket_echo_demo`) use Production.
  Convenience `NewHttpServerWithRequestArena` (no explicit options) also bases
  on **Production** + RequestArena so arena demos inherit finite RW defaults.
- **With* chain / Timeout vs ConnectTimeout / Default vs Production**：权威表见
  [`CONTRACT.md`](CONTRACT.md) §2.2「With* 链语义（Wave E2）」；勿在 README 双写细节。
- Cancel: `IHttpCancelToken` is **cooperative** → `hekCanceled` at Send /
  redirect / retry / H1 RoundTrip checkpoints, and mid-read/write via
  `ITcpStream.SetCancelToken`. **Unix**: waitable wake (socketpair+poll);
  **Windows**: waitable wake via TCP-loopback `platform_socket_pair` (PD-3-3).
  Prefer pairing with
  `Timeout`/`WithTimeout`. Timeouts remain `hekTimeout`. Details: CONTRACT §2.2.0.
- Timeouts: `THttpClientOptions.Timeout` = request read/write deadline after
  the socket is up; `ConnectTimeout` = **OS dial + post-dial first-write**
  budget on new sockets. When `ConnectTimeout=0`, dial uses `Timeout` if
  `Timeout>0`, else unbounded.
- `WithCookieJar(Jar)` — optional jar; Max-Age/Expires eviction; SameSite +
  eTLD+1 SiteKey (`HttpCookieSiteKey`; multi-label PSL subset; reject
  `Domain=public-suffix`)
  store/send (default Lax; None requires Secure; SiteKey approx, no PSL).
- `WithProxyUrl` / `THttpClientOptions.ProxyUrl` — plain HTTP forward proxy
  (`http://[user:pass@]host:port`). Target `http://` uses absolute-form; target
  `https://` uses CONNECT then TLS over the tunnel (origin-form). UserInfo →
  preemptive `Proxy-Authorization: Basic` only (no Digest/NTLM/407 challenge
  retry). Optional `TLSContext` / `WithTLSContext` for verify-none / custom trust;
  H1 direct https is supported without proxy.
- `WithDialFunc(Dial)` / `THttpClientOptions.DialFunc` — custom transport dial
  replacing the built-in TCP connect. `Dial` receives target host, port, and the
  effective connect/request timeouts; must return an established `ITcpStream` or
  raise `EHttpError`. Use case: SOCKS5/other tunnel transports where only the
  dial differs from direct (TLS and HTTP framing stay built-in). Connections are
  pooled per target authority. Precedence: `WithProxyUrl` > `DialFunc` >
  built-in dial. For raw SOCKS5 dialing see `nextpas.core.net.socks5.Socks5Dial`.
- `IHttpClient.GetString` / `GetBytes` and free `HttpGetString` / `HttpGetBytes`.
- `IHttpClient.GetJson` and free `HttpGetJson` / `HttpReadResponseJson`
  (ensure 2xx + JSON document; invalid body → `hekProtocol` Op=`json`).
- H1 default `User-Agent: nextpas-http/1.0` when the request omits it.
- `PostMultipart(Url, Fields, Files)` — multipart/form-data convenience POST.
- `IHttpClient.Send` owns any close-capable request body for the duration of the
  request. After the final round trip or failure, `IReadCloser` / `ICloser` /
  `IStream` request bodies are closed.
- `CloseIdleConnections` is a lifecycle seam for explicitly releasing idle
  keep-alive state. The public client does not leak H1 pool details; transports
  that own idle pooled connections may implement the optional capability and
  unsupported transports safely no-op.
- If a transport returns nil from `RoundTrip`, `IHttpClient.Send` raises
  `EHttpError` instead of leaking a nil-response access violation through the
  client facade.
- If a stale pooled keep-alive connection fails during `RoundTrip`, the client
  only retries automatically when the request is retry-safe and the body is
  replayable. Retry-safe means `GET` / `HEAD` / `OPTIONS` / `TRACE`, or an
  explicit `Idempotency-Key` / `X-Idempotency-Key`. Non-retry-safe requests and
  non-replayable non-empty bodies fail fast instead of silently sending a
  second request with changed semantics.
- Client redirects follow `301` / `302` / `303` by replaying as `GET` with no body;
  `307` / `308` preserve the original method and replay body readers that support
  `IStream` rewind. Non-empty non-replayable bodies raise `EHttpError` instead
  of silently sending an empty follow-up request.
- When a `301` / `302` / `303` follow-up drops the original request body, the
  client closes the original close-capable body before issuing the follow-up and
  does not close it a second time after `Send` returns.
- Redirect follow-up requests inherit caller headers. Cross-authority redirects
  strip `Authorization`, `WWW-Authenticate`, `Cookie`, and `Cookie2`; bodyless
  `301` / `302` / `303` follow-ups also drop `Content-Length` /
  `Transfer-Encoding`. Caller-specified `Host` is preserved for relative and
  same-authority redirects, including omitted-port vs. default-port equivalents,
  but dropped when the redirect changes authority so the transport derives the
  host from the new URL.
- Relative, path-relative, and network-path redirect `Location` values are
  resolved before the follow-up request is passed to the transport. Absolute
  `http` / `https` redirect schemes are matched case-insensitively and
  normalized to lowercase for the follow-up request; any absolute `Location`
  with another scheme, including non-hierarchical `scheme:` forms, raises
  `EHttpError` before a second round trip. Path-relative redirects merge
  against the original request directory and normalize dot segments, while
  network-path URLs inherit the original scheme and replace
  authority/path/query/fragment. Fragment-only redirects preserve the original
  path/query and update only the request URL fragment; H1 request writing still
  omits fragments from the wire request-target.
- Redirect responses that are followed or discarded by redirect errors are not
  returned to the caller. Before the follow-up round trip, or before raising a
  redirect error such as too many redirects, missing `Location`, or unsupported
  absolute scheme, the client releases the previous response body:
  close-capable readers are closed, and plain `IReader` bodies are drained to
  EOF. This keeps injected/future streaming transports from leaking an
  abandoned redirect body into connection reuse.
- `HttpGetToWriter(Client, Url, Writer)` — copies a successful GET response body to an `IWriter` and returns the byte count; non-2xx responses raise `EHttpError`; consumed or discarded response bodies are released before the helper returns or raises
- `HttpGetToFile(Client, Url, Path)` — writes a successful GET response through a same-directory temp file, atomically publishes the final path, cleans partial temp files on failure, and releases the response body before returning or raising
- `HttpReadResponseBodyBytes(Resp)` — consumes `Resp.Body` into `TBytes`; nil body returns empty bytes, nil response raises `EHttpError(hekArgument)`
- `HttpReadResponseBodyString(Resp)` — consumes `Resp.Body` into a Pascal string; nil body returns `''`, nil response raises `EHttpError(hekArgument)`
- `HttpReleaseResponseBody(Resp)` — releases a response body the caller will
  not read: close-capable bodies are closed, plain `IReader` bodies are drained
  to EOF, nil body is a no-op, and nil response raises `EHttpError(hekArgument)`
- `NewHttpServer(Handler[, Transport][, Options])` — 默认路径通过 internal registry 解析到 H1，也可显式注入 `IHttpServerTransport`
- `THttpServerOptions` — 公开 carrier（`Backend`、timeouts、`MaxHeaderSize`、
  `MaxBodySize`…）。`Default` vs `Production` 见上。Negative timeout or
  size-limit fields raise `EHttpError(hekArgument)` at server construction time.
- `NewHttpClient([Transport][, Options])` — 默认路径通过 internal registry 解析到 H1，也可显式注入 `IHttpTransport`
- `THttpClientOptions` — 公开 carrier，当前包括 `Timeout`、`ConnectTimeout`
  （OS dial + post-dial 首写 budget）、`MaxRedirects` 和 `FollowRedirects`;
  negative `Timeout` or `MaxRedirects` raises `EHttpError(hekArgument)` at
  client construction time.

### SSE

- `StartSSE(Writer)` / `ISSEEventWriter` — Server-Sent Events writer.
  Nil writer, field injection (CR/LF in event name/id), and negative retry
  raise `EHttpError(hekArgument)` (same public precondition style as client/
  server/websocket).

### WebSocket

- `UpgradeWebSocket(Req, Writer[, Options])` — 升级 HTTP 连接并返回 handler-owned `IWebSocket`
- `ConnectWebSocket(Url[, Options])` — 客户端 dial + upgrade；生产路径有界
- `TWebSocketOptions` — `MaxFrameSize` / `MaxMessageSize` / `ConnectTimeout` / `Timeout` /
  `OnCheckOrigin`；fluent `WithConnectTimeout` / `WithTimeout`
- `TWebSocketOptions.Default` — 16 MiB frame / 64 MiB message；**ConnectTimeout=Timeout=30000**
  （OS dial + handshake I/O）；`=0` 显式恢复无界

`MaxFrameSize` 在 payload 分配/读取前检查 declared frame length；`MaxMessageSize`
会累计 fragmented message，超过限制时由 `ReadFrame` 抛出 `EHttpError`。
`WriteText` 会在写出前拒绝 invalid UTF-8 payload，避免 server API 生成非法 text frame。
`Ping`、`Pong` 与 `Close` 也会在写出前拒绝超过 125 bytes 的 control-frame payload；
`Close` 会同时校验 close code 与 reason UTF-8，失败前不会关闭 `IWebSocket` 状态。

`THttpServerOptions.Backend` 会下沉到 `nextpas.core.net.server` foundation。
当前默认值是 `TCP_SERVER_BACKEND_THREADED`。在 Linux 上，
`TCP_SERVER_BACKEND_EPOLL` 已有第一阶段 backend：`epoll` 负责 listener
readiness 与 accept，accepted connection 仍交给 foundation worker 执行同步
HTTP handler，所以 public HTTP contract 保持不变。`kqueue` 在 macOS/FreeBSD
为 readiness 命名入口（compile truth）。Windows `TCP_SERVER_BACKEND_IOCP`
已有 phase-1：`net.server.iocp` 用 AcceptEx 做 completion-driven accept，
再 worker handoff 执行同步 handler（Wine smoke：`test_http_iocp_wine`；
**非** scale-ready / **非** real-Windows host 全量宣称）。非对应平台显式选择
未注册 backend 仍会得到 `ENotSupportedError`。后续 IOCP 可在 foundation 内
扩展 completion-driven per-conn path，而不改 public HTTP facade。

## Cross-Platform

Current transport implementation depends on `nextpas.core.net` (TCP) and
`nextpas.core.io` (stream interfaces). The current H2 slice keeps the public
HTTP facade stable while adding two transport modes behind the registry seam:
cleartext H2 uses prior-knowledge preface on `http://`, and TLS H2 uses strict
ALPN negotiation on `https://`. HTTP/1.1 `Upgrade: h2c` / `HTTP2-Settings`
upgrade is not exposed yet; cleartext H2 is direct H2 only. Future H3 work will
extend the transport family with QUIC when that protocol family is actually
implemented.

## Benchmarks

Run the focused server benchmark:

```sh
make -C benchmarks/nextpas.core.http/bench_server run
```

For smoke-sized runs, pass explicit scale knobs:

```sh
build/projects/nextpas.core.http/bench_server/bench_http_server --requests 1000 --threads 4
```

Run the focused router dispatch benchmark:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='handler dispatch' \
make -C benchmarks/nextpas.core.http/bench_router clean run
```

This emits `operation=http.router.dispatch` and a `handler dispatch` row for
route match plus no-op handler invocation, without H1 parsing or socket I/O.

Run the focused header lookup benchmark:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='Get hit' \
make -C benchmarks/nextpas.core.http/bench_headers clean run
```

This emits `operation=http.headers` and lowercase / uppercase lookup rows for
`THttpHeaders.Get`, without H1 parsing or socket I/O.

Run the focused H1 response serialization benchmark:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='headers only 200' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fixed 200 13B' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

This emits `operation=http.h1writer.serialize`. Use `headers only 200` to
isolate writer construction and fixed response header serialization, then
compare with `fixed 200 13B` to include the small body write into an in-memory
sink.

Run the focused H1 outbound drain benchmark:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='buffer write+drain 1KB' \
make -C benchmarks/nextpas.core.http/bench_h1outbound clean run
```

This emits `operation=http.h1outbound.drain` and a `buffer write+drain 1KB`
row for the internal outbound buffer write and in-memory drain path.

Run the filtered full-chain keep-alive benchmark:

```sh
NEXTPAS_BENCH_MAX_ITERS=1000 \
NEXTPAS_BENCH_FILTER=plaintext \
make -C benchmarks/nextpas.core.http/bench_fullchain clean run
```

This emits `operation=http.fullchain.keepalive` and a `workload=plaintext` row;
`workload=middleware_noop` is the matching `GET /` router row with one no-op
middleware layer. Keep the captured row with its truth markers:
`request_body_bytes`, `response_body_bytes`, `backend`, `nextpas_h1_path`,
`nextpas_dispatch_path`, `nextpas_dispatch_path=middleware_router`,
`observed_direct_handler_hits`, `observed_router_handler_hits`,
`observed_middleware_hits`, `client_read_mode=buffered`, `iterations`,
`completed`, `elapsed_ns`, `ns/op`, and `req/s`. If
`NEXTPAS_BENCH_FILTER` matches no scenario, the benchmark exits non-zero and
prints the unmatched filter instead of emitting a misleading row.

Run the focused comparator smoke from the test harness:

```sh
make -C tests/nextpas.core.http/test_http_benchmarks test
```

The harness builds and runs nextPas, Go, Rust std-only, and Hyper/Tokio
keep-alive server benchmarks at smoke scale. Each implementation reports
`operation`, `workload`, `impl`, `iterations`, `threads`, `completed`,
`elapsed_ns`, `ns/op`, and `req/s`, so later benchmark result capture can use
one stable format. The std-only Rust row is labeled `impl=rust_std` and also
reports `rust_profile=std_only`; the Hyper/Tokio row is labeled
`impl=rust_hyper` and reports `rust_profile=hyper_tokio`,
`rust_http_stack=hyper_http1`, and `rust_runtime=tokio_multi_thread`. The
harness also builds `bench_headers` and `bench_fullchain`, validating filtered
header lookup and plaintext full-chain row markers.

For manual comparison runs, use the server comparison runner:

```sh
benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/report.txt
```

The runner builds the default nextPas / Go / Rust std-only implementations,
streams the combined output to stdout, and optionally writes the same report to
`--output`; that path must stay under
`build/projects/nextpas.core.http/server_comparison` to keep benchmark reports
out of source and test trees. Use `--runs N` to repeat each implementation
after one build and print median `ns/op` / `req/s` summary rows. Use
`--workload url_path` to make the client request `/api/v1/users` and make each
server implementation touch the request path before writing the response. Use
`--workload adapter_no_url` to keep the handler no-URL while adding
`Connection: keep-alive`; current nextPas reports the actual route with
`nextpas_h1_path`, because explicit HTTP/1.1 keep-alive is fast-path compatible
while `close`, `upgrade`, and unsupported connection-policy tokens still fall
back to the llhttp adapter path. Use `--workload response_1k` to write and read
a complete 1 KiB fixed-length response body.
Pass `--include-hyper` when you want the optional Cargo-based Hyper/Tokio
comparator included in the same runner output and median summary. Summary rows
preserve Rust identity through `summary_rust_profile`,
`summary_rust_http_stack`, and `summary_rust_runtime`.

To capture environment metadata and the comparison output in Markdown, run:

```sh
benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh \
  --requests 20000 --threads 4 --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/snapshot.md
```

The snapshot includes `git_head`, OS, FPC, Go, and Rust versions, the benchmark
parameters including `runs`, and the raw comparison output plus summary rows.
Treat snapshots as local evidence, not as a permanent ranking across machines.
It uses the same `server_comparison` output-root guard and removes the adjacent
`${output}.raw` temp file after embedding the raw comparison output.

For narrowed `Pascal raw llhttp vs C llhttp` work, use the H1 parser flag
matrix runner instead of repeating separate single-shot commands:

```sh
LLHTTP_ROOT=/path/to/llhttp-9.4.1 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh \
  --smoke --no-perf --runs 3
```

`NEXTPAS_BENCH_FILTER` is a case-insensitive substring over benchmark row
names. H1 parser, full-chain, and C llhttp comparator filters exit non-zero on
no-match instead of emitting an empty evidence row. `LLHTTP_ROOT` takes
precedence; `NEXTPAS_LLHTTP_ROOT` is accepted as a fallback for shared
test/benchmark environments.

This writes per-run `results.tsv`, aggregated `summary.tsv`, `env.txt`, and
logs under `build/projects/nextpas.core.http/bench_h1parser/flag_matrix/...`.
`NEXTPAS_FLAG_MATRIX_OUTPUT_DIR` must stay under that root. Do not commit
generated objects, binaries, `.raw` captures, flag-matrix outputs, perf logs,
or vendored llhttp sources.

See [BENCHMARKS.md](BENCHMARKS.md) for the current harness details and the
latest committed local snapshot.
