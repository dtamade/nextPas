# nextpas.core.http

HTTP module providing server and client capabilities with radix-tree routing,
middleware chaining, and a centralized internal transport registry.

## Architecture

```
Facade (nextpas.core.http) — single uses entry point
  Application layer: Request, Response, Headers, Router, Middleware
  Internal registry: default version -> transport factory
  Protocol layer: impl.h1 (landed), impl.h2/impl.h3 (planned)
```

Current built-in mapping is `hvHttp10` / `hvHttp11` -> H1, with `hvHttp11`
as the default client/server version.

## Quick Start

Run the examples instead of copy-pasting a partial snippet:

```sh
make -C examples/nextpas.core.http/http_hello_server run
make -C examples/nextpas.core.http/http_get_client run
make -C examples/nextpas.core.http/http_server_options_demo run
make -C examples/nextpas.core.http/http_websocket_echo_demo run
```

- `http_hello_server` shows `NewRouter`, `Router.Get(...)`,
  `Req.PathParam`, `Req.QueryParam`, `NewHttpServer(..., THttpServerOptions.Default)`,
  and `ListenAndServe`.
- `http_get_client` shows `NewHttpClient`, `Client.Get(URL)`, reading
  `IHttpResponse.Body`, and printing status / headers / body.
- `http_server_options_demo` shows `THttpServerOptions.Backend`,
  `WriteTimeout`, `MaxHeaderSize`, `MaxBodySize`, and a runnable `POST /echo`
  path where oversize request bodies are rejected before the handler.
- `http_websocket_echo_demo` shows `UpgradeWebSocket`, `IWebSocket.ReadFrame`,
  `WriteText`, and `Close` on a runnable `/ws` echo endpoint.
- The client defaults to `http://127.0.0.1:8080/hello/world?page=1`.
- The server-options demo defaults to `threaded` on `127.0.0.1:8081`; pass
  `epoll` as the first arg on Linux to exercise the readiness backend.

## API Reference

### Router

- `NewRouter` — create radix-tree router (implements IHttpRouter + IHttpHandler)
- `Handle(Method, Pattern, Handler)` — register route with path params (`:name`) and wildcards
- `Get/Head/Post/Put/Delete/Patch/Options/Connect/Trace(Pattern, Handler)` — public convenience methods on `IHttpRouter`
- `Use(Middleware)` — append middleware to the router chain

### Headers

- `NewHeaders` — create IHttpHeaders (case-insensitive, multi-value)
- `Set_/Add/Get/GetAll/Has/Del/Count/ForEach/Clone`

### URL Utilities

- `TUrl.Parse` — parse full/relative URLs into scheme, userinfo, host, port, path, query, and fragment fields
- `TUrl.ParseRequestTarget` — parse HTTP request-target strings; origin-form skips authority parsing, absolute-form remains compatible with `TUrl.Parse`, and asterisk/authority-form targets are preserved as `Path`
- `UrlEncode/UrlDecode` — percent encoding
- `ParseQueryString/EncodeQueryString` — query parameter handling

### Middleware

- `HandlerFunc(Func)` — wrap closure as IHttpHandler
- `Chain(Handler, [Middlewares])` — compose middleware stack

### Messages

- `NewRequest(Method, Url)` / `NewGetRequest(Path)` — build requests
- `NewResponse(Status, Headers, Body)` — build responses

### Server / Client (interfaces)

- `IHttpServer.ListenAndServe(Addr, Port)` / `Shutdown` / `LocalAddr` / `IsRunning`
- `IHttpClient.Do_(Req)` / `Get(Url)` / `Post(Url, ContentType, Body)`
- `NewHttpServer(Handler[, Transport][, Options])` — 默认路径通过 internal registry 解析到 H1，也可显式注入 `IHttpServerTransport`
- `THttpServerOptions` — 公开 carrier，当前包括 `Backend`、timeouts、`MaxHeaderSize`、`MaxBodySize`
- `NewHttpClient([Transport][, Options])` — 默认路径通过 internal registry 解析到 H1，也可显式注入 `IHttpTransport`

### WebSocket

- `UpgradeWebSocket(Req, Writer[, Options])` — 升级 HTTP 连接并返回 handler-owned `IWebSocket`
- `TWebSocketOptions` — 公开 carrier，当前包括 `MaxFrameSize` 与 `MaxMessageSize`
- `TWebSocketOptions.Default` — 默认限制为 16 MiB frame / 64 MiB message，调用方可按 endpoint 调整

`MaxFrameSize` 在 payload 分配/读取前检查 declared frame length；`MaxMessageSize`
会累计 fragmented message，超过限制时由 `ReadFrame` 抛出 `EHttpError`。
`WriteText` 会在写出前拒绝 invalid UTF-8 payload，避免 server API 生成非法 text frame。
`Ping`、`Pong` 与 `Close` 也会在写出前拒绝超过 125 bytes 的 control-frame payload；
`Close` 会同时校验 close code 与 reason UTF-8，失败前不会关闭 `IWebSocket` 状态。

`THttpServerOptions.Backend` 会下沉到 `nextpas.core.net.server` foundation。
当前默认值是 `TCP_SERVER_BACKEND_THREADED`。在 Linux 上，
`TCP_SERVER_BACKEND_EPOLL` 已有第一阶段 backend：`epoll` 负责 listener
readiness 与 accept，accepted connection 仍交给 foundation worker 执行同步
HTTP handler，所以 public HTTP contract 保持不变。`kqueue` / `IOCP` 仍未实现；
非 Linux 平台显式选择 `epoll` 也仍会得到 `ENotSupportedError`。后续 `kqueue`
会继续沿用当前 readiness-family session seam；Windows `IOCP` 则会保持相同
public HTTP contract，但通过 foundation 的 completion-aware runtime path 接入，
而不是把 HTTP facade 改成 event-loop-first API。

## Cross-Platform

Current transport implementation depends on `nextpas.core.net` (TCP) and
`nextpas.core.io` (stream interfaces). Future H2/H3 work will extend this with
TLS/ALPN and QUIC when those protocol families are actually implemented.

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

Run the focused H1 response serialization benchmark:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fixed 200 13B' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

This emits `operation=http.h1writer.serialize` and a `fixed 200 13B` row for
writer construction, fixed response header serialization, and body copy into an
in-memory sink.

Run the focused H1 outbound drain benchmark:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='buffer write+drain 1KB' \
make -C benchmarks/nextpas.core.http/bench_h1outbound clean run
```

This emits `operation=http.h1outbound.drain` and a `buffer write+drain 1KB`
row for the internal outbound buffer write and in-memory drain path.

Run the focused comparator smoke from the test harness:

```sh
make -C tests/nextpas.core.http/test_http_benchmarks test
```

The harness builds and runs nextPas, Go, and Rust keep-alive server benchmarks at
smoke scale. Each implementation reports `operation`, `workload`, `impl`,
`iterations`, `threads`, `completed`, `elapsed_ns`, `ns/op`, and `req/s`, so
later benchmark result capture can use one stable format.

For manual comparison runs, use the server comparison runner:

```sh
benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/report.txt
```

The runner builds all three implementations, streams the combined output to
stdout, and optionally writes the same report to `--output`. Use `--runs N` to
repeat each implementation after one build and print median `ns/op` / `req/s`
summary rows. Use
`--workload url_path` to make the client request `/api/v1/users` and make each
server implementation touch the request path before writing the response. Use
`--workload adapter_no_url` to keep the handler no-URL while adding
`Connection: keep-alive`, which forces nextPas through the llhttp adapter path
instead of the H1 fast path. Use `--workload response_1k` to write and read a
complete 1 KiB fixed-length response body.

To capture environment metadata and the comparison output in Markdown, run:

```sh
benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh \
  --requests 20000 --threads 4 --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/snapshot.md
```

The snapshot includes `git_head`, OS, FPC, Go, and Rust versions, the benchmark
parameters including `runs`, and the raw comparison output plus summary rows.
Treat snapshots as local evidence, not as a permanent ranking across machines.

For narrowed `Pascal raw llhttp vs C llhttp` work, use the H1 parser flag
matrix runner instead of repeating separate single-shot commands:

```sh
LLHTTP_ROOT=/path/to/llhttp-9.4.1 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh \
  --smoke --no-perf --runs 3
```

This writes per-run `results.tsv`, aggregated `summary.tsv`, `env.txt`, and
logs under `build/projects/nextpas.core.http/bench_h1parser/flag_matrix/...`.

See [BENCHMARKS.md](BENCHMARKS.md) for the current harness details and the
latest committed local snapshot.
