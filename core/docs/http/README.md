# nextpas.core.http

HTTP module providing server and client capabilities with radix-tree routing,
middleware chaining, and protocol-version isolation (H1/H2/H3).

## Architecture

```
Facade (nextpas.core.http) — single uses entry point
  Application layer: Request, Response, Headers, Router, Middleware
  Protocol layer: impl.h1 (text), impl.h2 (binary frames), impl.h3 (QUIC)
```

## Quick Start

```pascal
uses nextpas.core.http;

var Router: IHttpRouter;
Router := NewRouter;
Router.Handle(hmGet, '/hello/:name', procedure(const Req: IHttpRequest; const W: IHttpResponseWriter)
begin
  W.WriteHeader(HTTP_STATUS_OK);
  W.Write(PAnsiChar('Hello ' + Req.PathParam('name')), ...);
end);
```

## API Reference

### Router

- `NewRouter` — create radix-tree router (implements IHttpRouter + IHttpHandler)
- `Handle(Method, Pattern, Handler)` — register route with path params (`:name`) and wildcards
- `Get/Post/Put/Delete(Pattern, Handler)` — convenience methods

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

## Cross-Platform

Depends on `nextpas.core.net` (TCP/UDP) and `nextpas.core.io` (stream interfaces).
Protocol negotiation is transparent to application code.
