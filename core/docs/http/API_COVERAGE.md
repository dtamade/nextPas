# nextpas.core.http API Coverage Matrix

最近更新：2026-06-03

这份矩阵只记录公开 API 的覆盖状态，不替代测试输出。状态含义：

- **focused**：有直接面向该公开契约的测试。
- **integration**：通过端到端路径覆盖，但还缺少更窄的契约测试。
- **indirect**：被其他 API 或场景带到，不能单独证明契约。
- **gap**：公开面存在，但还没有足够测试证据。

## 当前结论

- `http.base`、headers、URL、message、router、middleware、server、H1 parser/scan/fast/writer 已有较强 focused 覆盖。
- `THttpClientOptions.Default` / `THttpServerOptions.Default` 现在由 `test_http_base` 直接锁定。
- `IHttpClient.Get/Post/Do_` 原本已覆盖；本轮补齐 `Put/Delete/Patch/Head` focused 覆盖。
- `IHttpTransport`、`IHttpServerTransport` 现在既有 focused shape 覆盖，也有 facade runtime 注入覆盖；internal registry 也已落地并有 focused proof。
- `IHttpHijacker` 已有 facade alias、writer 行为和 server ownership 覆盖。
- facade callback aliases 与 server/client overload 现在有直接 focused smoke。
- `TH1ResponseWriter` 边界覆盖现在包括预设 `Transfer-Encoding`、显式 `Content-Length` flush 路径、以及 chunked finalization 后拒绝继续写入。
- `IHttpClient` 现在有 focused chunked response / close-delimited response / truncated fixed-length response 读取覆盖，并且 client pooling 已改为依赖 parser 推导出的 keep-alive 语义。
- `H1 parser` 现在有 focused response reuse semantic 覆盖：close-delimited / `Content-Length` / HTTP/1.0 非 keep-alive / truncated fixed-length EOF rejection。
- `H1 parser` 现在也有 request-side chunked body focused 覆盖：正常解码、invalid chunk-size、malformed chunk extension、missing chunk-data CRLF、EOF truncation、`CL+TE` conflict 两种顺序的 parser error、以及 trailer 字段不污染普通请求头。
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
- `H1 parser` 现在也有 keep-alive `Content-Length` partial follow-up headers focused 覆盖：首个合法 fixed-length request 只消费自己的字节，不会被半截下一请求头污染。
- `H1 parser` 现在也有 `chunked + Connection: close + extra bytes after terminal chunk` focused 覆盖。
- `H1 parser` 现在也有 keep-alive chunked garbage tail focused 覆盖：首个合法 chunked request 只消费自己的字节，不会被后续垃圾尾巴污染。
- `H1 parser` 现在也有 keep-alive chunked partial follow-up request-line focused 覆盖：首个合法 chunked request 只消费自己的字节，不会被半截下一请求行污染。
- `H1 parser` 现在也有 keep-alive chunked partial follow-up headers focused 覆盖：首个合法 chunked request 只消费自己的字节，不会被半截下一请求头污染。
- `H1 parser` 现在也有 keep-alive chunked trailer-complete garbage tail / partial follow-up request-line / partial follow-up headers focused 覆盖：完整 trailer section 结束后仍只消费首个合法 request，且 trailer 声明头保留、实际 trailer field 不进入普通请求头。
- `H1 parser` 现在也有 keep-alive chunked trailer-complete valid pipelined next-request focused 覆盖：完整 trailer section 结束后，合法下一请求同样不会污染首个 request，且 trailer declaration / trailer isolation 契约保持不变。
- `H1 parser` 现在也有 keep-alive chunked trailer-complete partial follow-up request-line bridge proof：同样的半截 follow-up line 在后续字节补全后可以合法完成为第二个请求，因此不能被过早当成 malformed tail。
- `H1 parser` 现在也有 same-read pipelined request isolation focused 覆盖：普通 fixed-length 与 chunked 首请求都只消费自己的字节，不会被同包后续 request 污染。
- `IHttpServer` 现在有 inbound chunked request focused 覆盖：handler 可读 decoded body、`MaxBodySize` 对 chunked ingress 的跨 chunk 累加超限生效、invalid chunk-size 返回 `400`、malformed chunk extension 返回显式 `400`、missing chunk-data CRLF 返回显式 `400`、chunked/trailer EOF truncation 在 peer half-close 后返回显式 `400`、generic malformed request 返回显式 `400`、`HTTP/1.1 missing Host` 返回显式 `400`、`HTTP/1.0 missing Host` 仍允许、`HTTP/0.9 / no-version` 返回显式 `400`、`CRLF injection / request-line splitting` 返回显式 `400`、`negative Content-Length` 返回显式 `400`、`very long method` 返回显式 `400`、`CL+TE` conflict 两种顺序返回 `400`、duplicate `Content-Length` 返回显式 `400`、`null-byte header` 返回显式 `400`、trailer 声明头保留且 trailer 字段不进入普通请求头、oversize trailer 在后续 read 到达时仍受 `MaxHeaderSize` 限制并触发 `431` 或安全关闭，且异常 chunk 不进入 handler。
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
- `IHttpServer` 现在也有一条 server-layer current-truth proof：非 `Connection: close` `Content-Length` garbage tail 会先完成首个合法 request，再把尾巴作为 follow-up malformed request 返回 `400`；这条证据用于后续契约决策，尚未当作最终 public policy 冻结。
- `IHttpServer` 现在也有 keep-alive `Content-Length` partial follow-up request-line current-truth proof：首个合法 fixed-length request 会先完成并进入 handler，半截下一请求行在 peer half-close 后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive `Content-Length` partial follow-up headers current-truth proof：首个合法 fixed-length request 会先完成并进入 handler，半截下一请求头在 peer half-close 后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive chunked garbage tail current-truth proof：首个合法 chunked request 会先完成并进入 handler，尾巴随后作为 follow-up malformed request 返回 `400`；这条证据同样用于后续契约决策，尚未当作最终 public policy 冻结。
- `IHttpServer` 现在也有 keep-alive chunked partial follow-up request-line current-truth proof：首个合法 chunked request 会先完成并进入 handler，半截下一请求行在 peer half-close 后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive chunked partial follow-up headers current-truth proof：首个合法 chunked request 会先完成并进入 handler，半截下一请求头在 peer half-close 后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive chunked trailer-complete garbage tail / partial follow-up request-line / partial follow-up headers current-truth proof：完整 trailer section 结束后的尾巴不会污染首个请求，trailer 声明头仍保留、实际 trailer field 仍不暴露为普通 header，尾巴随后作为 follow-up malformed request 返回 `400`。
- `IHttpServer` 现在也有 keep-alive chunked trailer-complete valid pipelined next-request focused proof：同一连接中的第二个合法请求会继续完成，且首请求 handler/response/body/trailer contract 不会被污染。
- `IHttpServer` 现在也有 keep-alive chunked trailer-complete partial follow-up request-line bridge proof：首个请求的 `200` 会先正常返回，后续若把半截下一请求补全，第二个请求也会继续合法完成。
- `IHttpServer` 现在也有 same-write pipelined request isolation focused 覆盖：transport 会保留未消费尾巴，确保前一 request 的 handler/response 与后一 request 分离；该证明现在同时覆盖普通 fixed-length 与 chunked 首请求。
- `IHttpServer` 现在也有 malformed trailer focused 覆盖：非法 trailer field-name 与 trailer section EOF truncation 都会返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 fixed-length request body EOF truncation focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `IHttpServer` 现在也有 request-line / headers EOF truncation focused 覆盖：peer half-close 后返回显式 `400`，且不进入 handler。
- `test_http_security` 现在把 `CL+TE` conflict、invalid chunk size、malformed chunk extension、以及 truncated chunked EOF 都锁成 explicit `400` proof。
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
- `test_http_security` 现在也把 `truncated trailer field CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `truncated trailer section CR EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `chunk-extension line EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `chunk-data CRLF EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也把 `terminal 0 chunk ending EOF truncation` 锁成 explicit `400` proof。
- `test_http_security` 现在也包含 generic malformed request、`HTTP/1.1 missing Host`、`HTTP/0.9 / no-version`、`CRLF injection / request-line splitting`、`negative Content-Length`、`very long method`、`Content-Length + Connection: close + extra bytes after body`、`chunked + Connection: close + extra bytes after terminal chunk`、duplicate `Content-Length`、`null-byte header`、missing chunk-data CRLF、malformed trailer、fixed-length request body EOF truncation、以及 request-line / headers EOF truncation 的 raw-wire explicit `400` proof。
- `test_http_security` 现在也有 keep-alive `Content-Length` garbage tail safe-handling proof：首个请求先完成，尾巴随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive `Content-Length` partial follow-up request-line safe-handling proof：首个请求先完成，半截下一请求行随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive `Content-Length` partial follow-up headers safe-handling proof：首个请求先完成，半截下一请求头随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive chunked garbage tail safe-handling proof：首个请求先完成，尾巴随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive chunked partial follow-up request-line safe-handling proof：首个请求先完成，半截下一请求行随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive chunked partial follow-up headers safe-handling proof：首个请求先完成，半截下一请求头随后作为 follow-up malformed request 返回 `400`。
- `test_http_security` 现在也有 keep-alive chunked trailer-complete garbage tail / partial follow-up request-line / partial follow-up headers safe-handling proof：完整 trailer section 结束后首个请求仍先完成，尾巴随后作为 follow-up malformed request 返回 `400`。
- `TChunkedWriter` 现在有独立 focused 覆盖，并且 helper 自身会在 terminal chunk 后拒绝继续写入。
- `WebSocket` 现在也有 upgrade read-ahead focused 覆盖：握手请求和首帧同包写入时，hijack 后依然能正确读到首帧。
- facade 覆盖主要来自 `test_http_contract` 和 `test_http_smoke`；后续如要进一步收紧，可再审视未转发 helper 是否也应进入 facade。

## Public Surface Matrix

| Surface                                        | Public contracts                                                                                                                                                                   | Coverage              | Evidence                                                                          | Next action                                                                                                               |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `nextpas.core.http` facade                     | type aliases, status constants, factory/forwarding functions                                                                                                                       | focused + integration | `test_http_contract`, `test_http_smoke`                                           | Revisit whether remaining helper entry points should also be consumable from the facade.                                  |
| `http.base`                                    | `THttpVersion`, `THttpMethod`, `THttpStatus`, `EHttpError`, `TUrl`, `THttpClientOptions.Default`, `THttpServerOptions.Default`                                                     | focused               | `test_http_base`, `test_http_contract`                                            | Add `EHttpError` code/category assertion if error contract is kept public.                                                |
| `IHttpHeaders` / `THttpHeaders`                | set/add/get/getall/has/del/count/foreach/clone, validation                                                                                                                         | focused               | `test_http_headers`, `test_http_contract`, `test_http_integration`                | Keep CRLF/name validation in focused security coverage.                                                                   |
| URL utilities                                  | encode/decode/query parse/query encode/value/has                                                                                                                                   | focused               | `test_http_url`, `test_http_contract`                                             | None in this phase.                                                                                                       |
| `IHttpRequest` / `THttpRequest`                | method/url/version/headers/body/content-length/remote/path/query params                                                                                                            | focused + integration | `test_http_message`, `test_http_server`, `test_http_integration`                  | Add direct `RemoteAddr` setter/getter unit coverage if it becomes public factory behavior.                                |
| `IHttpResponse` / `THttpResponse`              | status/headers/body                                                                                                                                                                | focused               | `test_http_message`, `test_http_contract`                                         | None in this phase.                                                                                                       |
| `IHttpResponseWriter` / `TH1ResponseWriter`    | write status, headers, body, flush, chunked default, no implicit close                                                                                                             | focused + integration | `test_http_h1writer`, `test_http_integration`, `test_http_server`                 | Keep writer state-machine coverage aligned with lower-level chunked helper behavior.                                      |
| `IHttpHandler` / `HandlerFunc`                 | handler wrapping and serving                                                                                                                                                       | focused               | `test_http_middleware`, `test_http_contract`                                      | Add nil-callback contract coverage only if nil guarding becomes part of the public API.                                   |
| `IHttpMiddleware` / `Chain` / `MiddlewareFunc` | wrapping, order, short-circuit, response mutation                                                                                                                                  | focused               | `test_http_middleware`, `test_http_middlewares`, `test_http_integration`          | None in this phase.                                                                                                       |
| `IHttpRouter` / `THttpRouter`                  | handle/use/get/head/post/put/delete/patch/options/serve, params, wildcard, method dispatch, 404/405                                                                               | focused + integration | `test_http_router`, `test_http_contract`, `test_http_integration`                 | Decide later whether `Connect/Trace` convenience methods belong in public router API.                                     |
| `IHttpServer` / `THttpServer`                  | listen/shutdown/local addr, limits, keep-alive, request body, chunked request decode, malformed chunk rejection, generic malformed request explicit `400` rejection, `HTTP/1.1 missing Host` explicit `400` rejection with `HTTP/1.0` compatibility preserved, `HTTP/0.9 / no-version` explicit `400` rejection, `CRLF injection / request-line splitting` explicit `400` rejection, `negative Content-Length` explicit `400` rejection, `very long method` explicit `400` rejection, `Content-Length + Connection: close + extra bytes after body` explicit `400` rejection, `chunked + Connection: close + extra bytes after terminal chunk` explicit `400` rejection, same-write pipelined request isolation for fixed-length and chunked first requests, intentional keep-alive request-tail transport policy: fixed-length / plain chunked / trailer-complete chunked requests always complete once the current request framing is complete, unread tail bytes stay buffered for the next request, malformed follow-up requests become follow-up `400` only after they are conclusively malformed or EOF-truncated, CL+TE conflict rejection, duplicate `Content-Length` explicit `400` rejection, `null-byte header` explicit `400` rejection, malformed chunk extension explicit `400` rejection, missing chunk-data CRLF explicit `400` rejection, terminal chunk ending CR EOF truncation explicit `400` rejection, terminal chunk extension EOF truncation explicit `400` rejection, terminal chunk ending after extension EOF truncation explicit `400` rejection, terminal chunk ending after extension CR EOF truncation explicit `400` rejection, truncated trailer field-name EOF truncation explicit `400` rejection, truncated trailer separator EOF truncation explicit `400` rejection, truncated trailer empty-value CR EOF truncation explicit `400` rejection, truncated trailer empty-value EOF truncation explicit `400` rejection, truncated trailer empty-value section CR EOF truncation explicit `400` rejection, truncated trailer whitespace EOF truncation explicit `400` rejection, truncated trailer whitespace CR EOF truncation explicit `400` rejection, truncated trailer whitespace section EOF truncation explicit `400` rejection, truncated trailer whitespace section CR EOF truncation explicit `400` rejection, truncated trailer field line EOF truncation explicit `400` rejection, truncated trailer field CR EOF truncation explicit `400` rejection, truncated trailer section CR EOF truncation explicit `400` rejection, chunk-extension line EOF truncation explicit `400` rejection, chunk-size line EOF truncation explicit `400` rejection, chunk-data CRLF EOF truncation explicit `400` rejection, terminal 0 chunk ending EOF truncation explicit `400` rejection, chunked trailer isolation, oversize trailer `431` rejection before handler dispatch, malformed trailer explicit `400` rejection before handler dispatch, fixed-length request body EOF truncation explicit `400`, request-line/header EOF truncation explicit `400`, remote addr, explicit transport injection, registry-backed default resolution | focused + integration | `test_http_server`, `test_http_smoke`, `test_http_contract`, `test_http_registry`, `test_http_security` | Keep ownership/limit coverage tight as H1 behavior evolves; next revisit this only if a new transport design intentionally changes buffering semantics. |
| `IHttpClient` / `THttpClient`                  | do/get/post/put/delete/patch/head, redirects, timeout, host header, pooling, chunked/EOF/truncated body handling, explicit transport injection, registry-backed default resolution | focused               | `test_http_client`, `test_http_smoke`, `test_http_contract`, `test_http_registry` | Consider adding a same-client follow-up regression if later transport refactors reopen pooling behavior.                  |
| `IHttpTransport`                               | `RoundTrip`, facade client injection, constructor default resolution                                                                                                               | focused               | `test_http_contract`, `test_http_registry`                                        | Keep registration internal until H2/H3 transports are real; widen to public API only if there is a clear external need.   |
| `IHttpServerTransport`                         | `ServeConn`, facade server injection, constructor default resolution                                                                                                               | focused               | `test_http_contract`, `test_http_registry`                                        | Keep registration internal until H2/H3 transports are real; add protocol-family coverage when new server transports land. |
| `IHttpHijacker` / `TH1ResponseWriter.Hijack`   | facade alias, connection takeover, server ownership transfer                                                                                                                       | focused + integration | `test_http_contract`, `test_http_h1writer`, `test_http_server`                    | Add exception-after-hijack and websocket upgrade ownership regression tests later.                                        |
| Static serving                                 | `ServeFile`, `ServeDir`                                                                                                                                                            | focused               | `test_http_static`                                                                | Add helper-level MIME tests only if helper API becomes public.                                                            |
| WebSocket                                      | upgrade, frame read/write, ping/pong/close, coalesced first-frame after hijack                                                                                                    | focused               | `test_http_websocket`                                                             | Add negative frame/oversize tests later.                                                                                  |
| H1 parser                                      | request/response parser API, response keep-alive inference, truncated fixed-length EOF rejection, chunked request decode/error/truncation, request fixed-length body EOF truncation, request-line/header EOF truncation, malformed chunk extension rejection, missing chunk-data CRLF rejection, terminal chunk ending CR EOF truncation rejection, terminal chunk extension EOF truncation rejection, terminal chunk ending after extension EOF truncation rejection, terminal chunk ending after extension CR EOF truncation rejection, truncated trailer field-name EOF truncation rejection, truncated trailer separator EOF truncation rejection, truncated trailer empty-value CR EOF truncation rejection, truncated trailer empty-value EOF truncation rejection, truncated trailer empty-value section CR EOF truncation rejection, truncated trailer whitespace EOF truncation rejection, truncated trailer whitespace CR EOF truncation rejection, truncated trailer whitespace section EOF truncation rejection, truncated trailer whitespace section CR EOF truncation rejection, truncated trailer field line EOF truncation rejection, truncated trailer field CR EOF truncation rejection, truncated trailer section CR EOF truncation rejection, chunk-extension line EOF truncation rejection, chunk-size line EOF truncation rejection, chunk-data CRLF EOF truncation rejection, terminal 0 chunk ending EOF truncation rejection, generic malformed request rejection, `HTTP/0.9 / no-version` rejection, `CRLF injection / request-line splitting` rejection, `negative Content-Length` rejection, `very long method` rejection, `Content-Length + Connection: close + extra bytes after body` rejection, intentional keep-alive request-tail isolation: current request completes first, tail bytes are left for the next parse pass, partial follow-up bytes may later complete into a valid second request, conclusively malformed or EOF-truncated follow-up requests reject on the follow-up parse only, `chunked + Connection: close + extra bytes after terminal chunk` rejection, trailer isolation from ordinary headers, late trailer byte accounting, malformed trailer rejection, `CL+TE` conflict rejection, duplicate `Content-Length` rejection, `null-byte header` rejection, same-read pipelined request isolation for fixed-length and chunked first requests | focused               | `test_http_h1parser`, `test_http_server`, `test_http_security`                    | Continue malformed-framing audit only where still-unclassified terminal/trailer grammar remains, and revisit transport policy only if buffering semantics intentionally change. |
| H1 scan                                        | CRLF/double CRLF/colon/token scan                                                                                                                                                  | focused               | `test_http_h1scan`                                                                | Benchmark after correctness phase.                                                                                        |
| H1 fast parser                                 | fast request parse result                                                                                                                                                          | focused               | `test_http_h1fast`                                                                | Keep differential tests against llhttp.                                                                                   |
| H1 chunked writer                              | chunk framing, hex length, zero-length write, terminal chunk, write-after-final                                                                                                    | focused               | `test_http_h1chunked`, `test_http_h1writer`, `test_http_server`                   | Add malformed chunk parser coverage in parser/security suites rather than expanding writer helper scope.                  |

## Highest-Priority Gaps

1. decide whether a public trailer API is warranted; the current narrow contract is to preserve the `Trailer` declaration header but ignore trailer fields in ordinary headers.
2. facade helper boundary audit to decide which non-forwarded helpers should stay unit-local versus move into `nextpas.core.http`.
3. future H2/H3 transport registration coverage on the landed internal registry.
4. continue malformed chunk/trailer audit only if still-unclassified terminal/trailer grammar subclasses are found during later protocol work.
