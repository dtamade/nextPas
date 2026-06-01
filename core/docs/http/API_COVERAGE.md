# nextpas.core.http API Coverage Matrix

最近更新：2026-06-02

这份矩阵只记录公开 API 的覆盖状态，不替代测试输出。状态含义：

- **focused**：有直接面向该公开契约的测试。
- **integration**：通过端到端路径覆盖，但还缺少更窄的契约测试。
- **indirect**：被其他 API 或场景带到，不能单独证明契约。
- **gap**：公开面存在，但还没有足够测试证据。

## 当前结论

- `http.base`、headers、URL、message、router、middleware、server、H1 parser/scan/fast/writer 已有较强 focused 覆盖。
- `IHttpClient.Get/Post/Do_` 原本已覆盖；本轮补齐 `Put/Delete/Patch/Head` focused 覆盖。
- `IHttpTransport`、`IHttpServerTransport`、`IHttpHijacker`、`THttpHandlerMethod`、`THttpHandlerProc` 仍是优先缺口。
- facade 覆盖主要来自 `test_http_contract` 和 `test_http_smoke`，下一步需要把“只 uses `nextpas.core.http`”的 facade smoke 范围再收紧。

## Public Surface Matrix

| Surface                                        | Public contracts                                                                                  | Coverage              | Evidence                                                                 | Next action                                                                                                              |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `nextpas.core.http` facade                     | type aliases, status constants, factory/forwarding functions                                      | integration           | `test_http_contract`, `test_http_smoke`                                  | Add facade-only compile/smoke assertions for server/client overloads and callback aliases.                               |
| `http.base`                                    | `THttpVersion`, `THttpMethod`, `THttpStatus`, `EHttpError`, `TUrl`, method/status/version helpers | focused               | `test_http_base`, `test_http_contract`                                   | Add `EHttpError` code/category assertion if error contract is kept public.                                               |
| `IHttpHeaders` / `THttpHeaders`                | set/add/get/getall/has/del/count/foreach/clone, validation                                        | focused               | `test_http_headers`, `test_http_contract`, `test_http_integration`       | Keep CRLF/name validation in focused security coverage.                                                                  |
| URL utilities                                  | encode/decode/query parse/query encode/value/has                                                  | focused               | `test_http_url`, `test_http_contract`                                    | None in this phase.                                                                                                      |
| `IHttpRequest` / `THttpRequest`                | method/url/version/headers/body/content-length/remote/path/query params                           | focused + integration | `test_http_message`, `test_http_server`, `test_http_integration`         | Add direct `RemoteAddr` setter/getter unit coverage if it becomes public factory behavior.                               |
| `IHttpResponse` / `THttpResponse`              | status/headers/body                                                                               | focused               | `test_http_message`, `test_http_contract`                                | None in this phase.                                                                                                      |
| `IHttpResponseWriter` / `TH1ResponseWriter`    | write status, headers, body, flush, chunked default, no implicit close                            | focused + integration | `test_http_h1writer`, `test_http_integration`, `test_http_server`        | Add pre-set `Transfer-Encoding` and explicit `Content-Length` boundary tests.                                            |
| `IHttpHandler` / `HandlerFunc`                 | handler wrapping and serving                                                                      | focused               | `test_http_middleware`, `test_http_contract`                             | Add callback-alias compile tests for `THttpHandlerMethod` and `THttpHandlerProc`.                                        |
| `IHttpMiddleware` / `Chain` / `MiddlewareFunc` | wrapping, order, short-circuit, response mutation                                                 | focused               | `test_http_middleware`, `test_http_middlewares`, `test_http_integration` | None in this phase.                                                                                                      |
| `IHttpRouter` / `THttpRouter`                  | handle/use/serve, params, wildcard, method dispatch, 404/405                                      | focused + integration | `test_http_router`, `test_http_integration`                              | Decide whether `Patch/Head/Options` convenience methods belong in public router API.                                     |
| `IHttpServer` / `THttpServer`                  | listen/shutdown/local addr, limits, keep-alive, request body, remote addr                         | focused + integration | `test_http_server`, `test_http_smoke`                                    | Add focused `NewHttpServer` overload coverage through facade.                                                            |
| `IHttpClient` / `THttpClient`                  | do/get/post/put/delete/patch/head, redirects, timeout, host header, pooling                       | focused               | `test_http_client`, `test_http_smoke`                                    | Add chunked response and close-delimited response coverage next.                                                         |
| `IHttpTransport`                               | `RoundTrip`                                                                                       | gap                   | none                                                                     | Define whether this is an extension seam or planned registry contract; add mock transport contract tests after decision. |
| `IHttpServerTransport`                         | `ServeConn`                                                                                       | gap                   | none                                                                     | Define protocol-registration ownership before testing.                                                                   |
| `IHttpHijacker` / `TH1ResponseWriter.Hijack`   | connection takeover                                                                               | gap                   | websocket path is adjacent but not a direct contract test                | Add focused hijack lifecycle test before expanding websocket/server upgrade work.                                        |
| Static serving                                 | `ServeFile`, `ServeDir`                                                                           | focused               | `test_http_static`                                                       | Add helper-level MIME tests only if helper API becomes public.                                                           |
| WebSocket                                      | upgrade, frame read/write, ping/pong/close                                                        | focused               | `test_http_websocket`                                                    | Add negative frame/oversize tests later.                                                                                 |
| H1 parser                                      | request/response parser API                                                                       | focused               | `test_http_h1parser`, `test_http_security`                               | Add more malformed chunked/body edge cases in H1 hardening phase.                                                        |
| H1 scan                                        | CRLF/double CRLF/colon/token scan                                                                 | focused               | `test_http_h1scan`                                                       | Benchmark after correctness phase.                                                                                       |
| H1 fast parser                                 | fast request parse result                                                                         | focused               | `test_http_h1fast`                                                       | Keep differential tests against llhttp.                                                                                  |
| H1 chunked writer                              | chunk framing and final chunk                                                                     | indirect              | `test_http_h1writer`, `test_http_server`                                 | Add direct `TChunkedWriter` focused tests if it stays public implementation API.                                         |

## Highest-Priority Gaps

1. `IHttpTransport` / `IHttpServerTransport` contract shape.
2. `IHttpHijacker` lifecycle and ownership after hijack.
3. facade-only smoke coverage for callback aliases and server/client overloads.
4. H1 writer boundary tests for pre-set `Transfer-Encoding`, explicit `Content-Length`, and flush finalization.
