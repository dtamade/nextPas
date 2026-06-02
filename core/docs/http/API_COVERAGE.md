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
- `IHttpTransport`、`IHttpServerTransport` 现在既有 focused shape 覆盖，也有 facade runtime 注入覆盖；registry 仍未实现。
- `IHttpHijacker` 已有 facade alias、writer 行为和 server ownership 覆盖。
- facade callback aliases 与 server/client overload 现在有直接 focused smoke。
- `TH1ResponseWriter` 边界覆盖现在包括预设 `Transfer-Encoding`、显式 `Content-Length` flush 路径、以及 chunked finalization 后拒绝继续写入。
- `IHttpClient` 现在有 focused chunked response / close-delimited response 读取覆盖，并且 client pooling 已改为依赖 parser 推导出的 keep-alive 语义。
- `H1 parser` 现在有 focused response reuse semantic 覆盖：close-delimited / `Content-Length` / HTTP/1.0 非 keep-alive。
- `TChunkedWriter` 现在有独立 focused 覆盖，并且 helper 自身会在 terminal chunk 后拒绝继续写入。
- facade 覆盖主要来自 `test_http_contract` 和 `test_http_smoke`；后续如要进一步收紧，可再审视未转发 helper 是否也应进入 facade。

## Public Surface Matrix

| Surface                                        | Public contracts                                                                                   | Coverage              | Evidence                                                                 | Next action                                                                                                                  |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `nextpas.core.http` facade                     | type aliases, status constants, factory/forwarding functions                                       | focused + integration | `test_http_contract`, `test_http_smoke`                                  | Revisit whether remaining helper entry points should also be consumable from the facade.                                     |
| `http.base`                                    | `THttpVersion`, `THttpMethod`, `THttpStatus`, `EHttpError`, `TUrl`, method/status/version helpers  | focused               | `test_http_base`, `test_http_contract`                                   | Add `EHttpError` code/category assertion if error contract is kept public.                                                   |
| `IHttpHeaders` / `THttpHeaders`                | set/add/get/getall/has/del/count/foreach/clone, validation                                         | focused               | `test_http_headers`, `test_http_contract`, `test_http_integration`       | Keep CRLF/name validation in focused security coverage.                                                                      |
| URL utilities                                  | encode/decode/query parse/query encode/value/has                                                   | focused               | `test_http_url`, `test_http_contract`                                    | None in this phase.                                                                                                          |
| `IHttpRequest` / `THttpRequest`                | method/url/version/headers/body/content-length/remote/path/query params                            | focused + integration | `test_http_message`, `test_http_server`, `test_http_integration`         | Add direct `RemoteAddr` setter/getter unit coverage if it becomes public factory behavior.                                   |
| `IHttpResponse` / `THttpResponse`              | status/headers/body                                                                                | focused               | `test_http_message`, `test_http_contract`                                | None in this phase.                                                                                                          |
| `IHttpResponseWriter` / `TH1ResponseWriter`    | write status, headers, body, flush, chunked default, no implicit close                             | focused + integration | `test_http_h1writer`, `test_http_integration`, `test_http_server`        | Keep writer state-machine coverage aligned with lower-level chunked helper behavior.                                          |
| `IHttpHandler` / `HandlerFunc`                 | handler wrapping and serving                                                                       | focused               | `test_http_middleware`, `test_http_contract`                             | Add nil-callback contract coverage only if nil guarding becomes part of the public API.                                      |
| `IHttpMiddleware` / `Chain` / `MiddlewareFunc` | wrapping, order, short-circuit, response mutation                                                  | focused               | `test_http_middleware`, `test_http_middlewares`, `test_http_integration` | None in this phase.                                                                                                          |
| `IHttpRouter` / `THttpRouter`                  | handle/use/serve, params, wildcard, method dispatch, 404/405                                       | focused + integration | `test_http_router`, `test_http_integration`                              | Decide whether `Patch/Head/Options` convenience methods belong in public router API.                                         |
| `IHttpServer` / `THttpServer`                  | listen/shutdown/local addr, limits, keep-alive, request body, remote addr, explicit transport injection | focused + integration | `test_http_server`, `test_http_smoke`, `test_http_contract`              | Keep ownership/limit coverage tight as H1 behavior evolves; add registry resolution tests after `impl.registry` lands.      |
| `IHttpClient` / `THttpClient`                  | do/get/post/put/delete/patch/head, redirects, timeout, host header, pooling, chunked/EOF body read, explicit transport injection | focused               | `test_http_client`, `test_http_smoke`, `test_http_contract`              | Consider adding a same-client follow-up regression if later transport refactors reopen pooling behavior.                     |
| `IHttpTransport`                               | `RoundTrip`, facade client injection                                                               | focused               | `test_http_contract`                                                     | Add registry lookup/default-resolution tests after `impl.registry` is designed.                                              |
| `IHttpServerTransport`                         | `ServeConn`, facade server injection                                                               | focused               | `test_http_contract`                                                     | Add server protocol-registration/default-resolution tests after `impl.registry` is designed.                                 |
| `IHttpHijacker` / `TH1ResponseWriter.Hijack`   | facade alias, connection takeover, server ownership transfer                                       | focused + integration | `test_http_contract`, `test_http_h1writer`, `test_http_server`           | Add exception-after-hijack and websocket upgrade ownership regression tests later.                                           |
| Static serving                                 | `ServeFile`, `ServeDir`                                                                            | focused               | `test_http_static`                                                       | Add helper-level MIME tests only if helper API becomes public.                                                               |
| WebSocket                                      | upgrade, frame read/write, ping/pong/close                                                         | focused               | `test_http_websocket`                                                    | Add negative frame/oversize tests later.                                                                                     |
| H1 parser                                      | request/response parser API, response keep-alive inference                                         | focused               | `test_http_h1parser`, `test_http_security`                               | Add more malformed chunked/body edge cases in H1 hardening phase.                                                            |
| H1 scan                                        | CRLF/double CRLF/colon/token scan                                                                  | focused               | `test_http_h1scan`                                                       | Benchmark after correctness phase.                                                                                           |
| H1 fast parser                                 | fast request parse result                                                                          | focused               | `test_http_h1fast`                                                       | Keep differential tests against llhttp.                                                                                      |
| H1 chunked writer                              | chunk framing, hex length, zero-length write, terminal chunk, write-after-final                    | focused               | `test_http_h1chunked`, `test_http_h1writer`, `test_http_server`          | Add malformed chunk parser coverage in parser/security suites rather than expanding writer helper scope.                     |

## Highest-Priority Gaps

1. real `impl.registry` 默认协议解析/接线层，在 H2/H3 之前先把 owner 做实。
2. malformed chunk/body edge cases in parser/security focused tests.
3. facade helper boundary audit to decide which non-forwarded helpers should stay unit-local versus move into `nextpas.core.http`.
