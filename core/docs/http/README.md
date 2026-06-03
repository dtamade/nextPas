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
```

- `http_hello_server` shows `NewRouter`, `Router.Get(...)`,
  `Req.PathParam`, `Req.QueryParam`, `NewHttpServer(..., THttpServerOptions.Default)`,
  and `ListenAndServe`.
- `http_get_client` shows `NewHttpClient`, `Client.Get(URL)`, reading
  `IHttpResponse.Body`, and printing status / headers / body.
- The client defaults to `http://127.0.0.1:8080/hello/world?page=1`.

## API Reference

### Router

- `NewRouter` — create radix-tree router (implements IHttpRouter + IHttpHandler)
- `Handle(Method, Pattern, Handler)` — register route with path params (`:name`) and wildcards
- `Get/Head/Post/Put/Delete/Patch/Options(Pattern, Handler)` — public convenience methods on `IHttpRouter`
- `Use(Middleware)` — append middleware to the router chain

### Headers

- `NewHeaders` — create IHttpHeaders (case-insensitive, multi-value)
- `Set_/Add/Get/GetAll/Has/Del/Count/ForEach/Clone`

### URL Utilities

- `UrlEncode/UrlDecode` — percent encoding
- `ParseQueryString/EncodeQueryString` — query parameter handling

### Middleware

- `HandlerFunc(Func)` — wrap closure as IHttpHandler
- `Chain(Handler, [Middlewares])` — compose middleware stack

### Messages

- `NewRequest(Method, Url)` / `NewGetRequest(Path)` — build requests
- `NewResponse(Status, Headers, Body)` — build responses

### Server / Client (interfaces)

- `IHttpServer.ListenAndServe(Addr, Port)` / `Shutdown`
- `IHttpClient.Do_(Req)` / `Get(Url)` / `Post(Url, ContentType, Body)`
- `NewHttpServer(Handler[, Transport][, Options])` — 默认路径通过 internal registry 解析到 H1，也可显式注入 `IHttpServerTransport`
- `THttpServerOptions` — 公开 carrier，当前包括 `Backend`、timeouts、`MaxHeaderSize`、`MaxBodySize`
- `NewHttpClient([Transport][, Options])` — 默认路径通过 internal registry 解析到 H1，也可显式注入 `IHttpTransport`

`THttpServerOptions.Backend` 会下沉到 `nextpas.core.net.server` foundation。
当前默认值是 `TCP_SERVER_BACKEND_THREADED`；`epoll` / `kqueue` / `IOCP`
backend 还未实现时，显式选择它们会得到 `ENotSupportedError`。

## Cross-Platform

Current transport implementation depends on `nextpas.core.net` (TCP) and
`nextpas.core.io` (stream interfaces). Future H2/H3 work will extend this with
TLS/ALPN and QUIC when those protocol families are actually implemented.
