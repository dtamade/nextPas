# nextpas.core.http Goal Tree

> Last updated: 2026-07-16 (P1 — keep-alive request-tail contract final)
> Goal: make `nextpas.core.http` one of the best Free Pascal HTTP frameworks, with public API quality, correctness, lifecycle clarity, maintainability, and performance evidence that stand up against Go `net/http` and high-quality Rust HTTP stacks.

## North Star And Scope

`nextpas.core.http` should become a framework-quality HTTP module, not just a working H1 server/client:

- Public API first: handlers, router, client, headers, messages, static, and WebSocket surfaces must be coherent, testable, and stable before they are called complete.
- Correctness before ranking: malformed framing, redirect semantics, lifecycle, ownership, and timeout behavior must be proven before broad benchmark claims matter.
- HTTP should stay framework-shaped: synchronous public contracts, small interfaces, explicit ownership, and transport seams that do not leak runtime internals into consumers.
- Higher-level truth should improve lower layers: if HTTP reveals a bad contract in `net`, `async`, `platform`, `mem`, or `base`, the right fix is usually to improve the lower-layer contract, not to hide it behind an HTTP workaround.
- Evidence over slogans: public surface claims need focused tests; performance claims need isolated benchmarks or controlled comparators; cross-language claims need honest caveats.

This goal tree covers `core/src/nextpas.core.http*`, HTTP tests/examples/benchmarks, and HTTP module docs. It does not treat H2/H3 placeholders, static serving helpers, or WebSocket helpers as “done” simply because H1 is already strong.

## Current Position

This lane is in **G2/G3/G4/G5 active hardening / completion closure**:

- G0 control and module discipline already exist in `AGENTS.md`, `core/AGENTS.md`, and `core/docs/design-conventions.md`.
- G1 stable H1 public surface is largely landed: server/client/router/headers/url/message/middleware/static/websocket all exist and already have substantial focused coverage.
- G2 correctness and lifecycle proof is well advanced: threaded and Linux `epoll` paths have broad raw-wire/server proof, client redirect/body ownership semantics are materially tighter, and examples have runnable smoke coverage.
- G3 API and performance isolation is still active: client ergonomics landed builder/decorator/streaming/json/form surfaces; remaining work is surface audit and cost isolation, not unchecked expansion.
- G4 H2 transport is now landed: server session + client transport + TLS ALPN + connection pool + RFC 9113 compliance are all implemented with 207 focused tests. H2 is production-transport-ready, not just a foundation slice. All H2 test coverage gaps closed (client 55, frame 37, hpack 30). Session test hardening complete (55 tests, MaxConcurrentStreams check-order bug fixed).
- G5 Static graduation complete: range requests (RFC 7233), ETag, Last-Modified, Cache-Control, Content-Disposition all implemented with 21 focused tests. WebSocket server + client landed.
- H3 remains blocked on the QUIC module (only QUIC crypto primitives exist).
- Module gate: `core/tests/nextpas.core.http/Makefile` now runs **34** focused suites; side suites are benchmarks/examples/smoke/integration/tls_real.

### Stage completion definition (non-H3)

HTTP can be called stage-complete only when all of these hold:

1. Public contracts and docs match source (`CONTRACT.md` / `ARCHITECTURE.md` / this tree).
2. Main Makefile gate is green with heaptrc-sensitive suites at `0 unfreed` where claimed.
3. H1 malformed/lifecycle/ownership open decisions are closed — keep-alive request-tail is **INV-12 final** (`CONTRACT.md` §3.1).
4. H2 is reachable from facade options with live proof; design exclusions remain explicit.
5. Runtime truth (threaded baseline + epoll poll path) is documented and not contradicted by gates.
6. Performance claims stay scoped; no fake H3 surface.

### Recent Fixes (2026-07-16)

**P1 (2026-07-16): Keep-alive request-tail contract final**

- Decision: **final public contract**, not provisional transport truth.
- Policy: framing-complete first request is delivered; unread tail is isolated into next-request pending buffer; partial follow-up must not be early-rejected; conclusively malformed / EOF-truncated follow-up becomes follow-up `400` after prior response; `Connection: close` + extra bytes stays same-request `400` with no handler.
- Recorded as **INV-12** in `CONTRACT.md` §3.1; implementation comment on `FPending` drain loop in `impl.h1`.
- Evidence already locked by `test_http_h1parser` + `test_http_server` + `test_http_security` (threaded/epoll garbage-tail / partial-complete / pipeline).
- Explicit non-goals: do not reclassify a complete first request as same-request `400` solely because keep-alive garbage follows.

**Slice 0 (2026-07-16): Control-plane truth + gate audit**

- Reconciled `CONTRACT.md` / `inbox.md` / this goal tree to current IHttp* surface, builder-first API, H2 status, and gate inventory.
- Expanded main HTTP Makefile gate: 27 → 34 suites (`base`, `url`, `router`, `middleware`, `static`, `h1scan`, `h1outbound`).
- Documented intentional side suites: `benchmarks`, `examples`, `smoke`, `integration`, `tls_real`.
- Fixed `test_http_router` 404/405 expectations to RFC 7807 Problem Details (`application/problem+json`).
- Fixed router group-test ownership cleanup and `THttpRouter.Destroy` middleware/regex handler release.
- Evidence: `test_http_router` 30 passed / 0 failed / 0 unfreed.

### Recent Fixes (2026-07-07)

**Phase 19 (2026-07-07): Streaming Request Body Ownership API**

- **`NewStreamingRequest`**: factory functions that create `IHttpRequest` with a non-buffered `IReader` body — the body is passed directly to the transport, not read into memory
- **`IHttpClient.SendStreaming`**: sends a streaming request with explicit body ownership contract — `Send` takes ownership and closes the body after the round trip (success or error)
- **Body ownership contract**: documented in `NewStreamingRequest` docstring — caller creates body, `Send` closes it; for redirects, non-seekable streams raise `EHttpError('redirect request body is not replayable')`
- **Decorator support**: `TAuthClient`/`THeaderClient`/`TOptionsOverrideClient` all implement `SendStreaming` with correct header injection and options merging
- **Re-exported**: `NewStreamingRequest` overloads available from `nextpas.core.http` facade
- **Tests**: 5 new tests (content-length, body closed after send, body closed on error, headers preserved, redirect ownership), 166 client total / 0 leaks

**Phase 18 (2026-07-07): Fluent Request Builder**

- **`THttpRequestBuilder`**: record type with fluent API for constructing `IHttpRequest` objects
- **Methods**: `Header`, `BasicAuth`, `BearerAuth`, `ContentType`, `Body` (string/TBytes/IReader), `QueryParam`, `Timeout`, `MaxRedirects`, `FollowRedirects`, `Build`
- **Query handling**: accumulates params and encodes via `EncodeQueryString` on `Build()`, preserves existing query in URL
- **Per-request options**: integrates with Phase 17's `IHttpRequestWithOptions` — `FollowRedirects(false)` etc. on the builder
- **Re-exported**: `THttpRequestBuilder` available from `nextpas.core.http` facade
- **Tests**: 8 new tests (GET, POST+body, headers+auth, BasicAuth, query params, existing query, per-request options, full chaining), 161 client total / 0 leaks

**Phase 17 (2026-07-07): Per-Request Redirect/Timeout Override**

- **`IHttpRequestWithOptions`**: new interface on `THttpRequest` carrying per-request `THttpRequestOptions` (timeout, follow-redirects, max-redirects)
- **`THttpRequestOptions`**: record with `Has*` flags and `Effective*(default)` accessors — cleanly distinguishes "not set" from explicit values
- **`IHttpClient`**: added `WithTimeout(ms)`, `WithMaxRedirects(n)`, `WithFollowRedirects(bool)` — per-request decorator methods
- **`TOptionsOverrideClient`**: new decorator that merges per-request overrides onto the request before delegating to the inner client
- **`THttpClient.Send/DoRequest`**: now check `IHttpRequestWithOptions` on the request for redirect behavior overrides
- **Chaining**: all decorator methods compose — `client.WithHeader('x', 'y').WithFollowRedirects(false).Get(url)` works correctly
- **Tests**: 5 new tests (WithFollowRedirects(false), WithMaxRedirects(0), chained decorator, override client default, WithTimeout), 153 client total / 0 leaks

**Phase 16 (2026-07-07): Response Charset Auto-Detection**

- **`HttpReadResponseBodyStringAuto(resp)`**: reads response body with charset auto-detection from Content-Type header
- **`ExtractCharsetFromContentType(ct)`**: extracts charset parameter from Content-Type (handles quotes, semicolons)
- **Charsets**: UTF-8, US-ASCII (default), ISO-8859-1/Latin-1/Windows-1252, fallback to raw bytes
- **Tests**: 4 new tests (charset extraction, UTF-8 auto, Latin-1 auto, no-charset default), 148 client total / 0 leaks

**Phase 15 (2026-07-07): THttpClientOptions Fluent Configuration**

- **`THttpClientOptions`**: added `WithTimeout(ms)`, `WithMaxRedirects(n)`, `WithFollowRedirects(bool)`, `WithMaxPoolSize(n)` — chainable configuration methods
- **Pattern**: `THttpClientOptions.Default.WithTimeout(10000).WithMaxRedirects(5).WithFollowRedirects(False)`
- **Tests**: 5 new tests (WithTimeout, WithMaxRedirects, WithFollowRedirects, WithMaxPoolSize, fluent chain), 30 base total / 0 leaks

**Phase 14 (2026-07-07): Delete Body Overloads + DeleteJson**

- **`IHttpClient`**: added `Delete(url, contentType, body)` overloads (IReader, string, TBytes) — parity with Post/Put/Patch
- **`IHttpClient`**: added `DeleteJson(url, body: TJsonValue)` — auto-serializes JSON + sets `application/json` content-type
- **`TAuthClient`/`THeaderClient`**: all three decorator classes implement the new Delete overloads and DeleteJson
- **Tests**: 2 new integration tests (Delete with body, DeleteJson), 144 client total / 0 leaks

**Phase 13 (2026-07-07): TUrl Query Parameter Methods**

- **`TUrl`**: added `AddQuery(name, value)` (percent-encodes, appends), `WithQuery(raw)` (replaces), `GetQueryParam(name)` (reads), `HasQueryParam(name)` (checks)
- **`nextpas.core.http.base`**: inline `PercentEncodeQueryValue` helper (space-as-+, RFC 3986 unreserved)
- **Tests**: 12 new TUrl method tests (basic, multiple, encoding, existing, replace, clear, read, empty, no-value, has, no-query, field preservation), 33 URL total / 0 leaks

**Phase 12 (2026-07-07): Client WithHeader Decorator**

- **`IHttpClient`**: added `WithHeader(name, value)` — returns new `IHttpClient` wrapper that injects arbitrary header on every request
- **`THeaderClient`**: generic decorator, chains with auth: `WithBearerAuth(token).WithHeader('Accept', 'application/json')`
- **Tests**: 4 new integration tests (custom header, chain with auth, multiple headers, original client unaffected), 142 client total / 0 leaks

**Phase 11 (2026-07-07): Client Auth Decorator**

- **`IHttpClient`**: added `WithBasicAuth(username, password)` / `WithBearerAuth(token)` — returns new `IHttpClient` wrapper with automatic `authorization` header injection
- **`TAuthClient`**: decorator pattern, builds requests itself via `BufferedBodyRequest` to inject auth header before delegating to inner client
- **Tests**: 4 new integration tests (Basic auth header, Bearer auth header, decorator delegation, original client unaffected), 138 client total / 0 leaks

**Phase 10 (2026-07-07): Client JSON Convenience**

- **`IHttpClient`**: added `PostJson`/`PutJson`/`PatchJson(url, body: TJsonValue)` — auto-serializes JSON + sets `application/json` content-type
- **`nextpas.core.http.intf`**: added `TJsonValue` type alias, `nextpas.core.json.value` dependency
- **Tests**: 1 new integration test (PostJson content-type + method verification), 136 client total / 0 leaks

**Phase 9 (2026-07-07): Client PostForm Convenience**

- **`IHttpClient`**: added `PostForm(url, fields)` — encodes `TFormFieldArray` as `application/x-www-form-urlencoded` and POSTs
- **`THttpClient`**: implementation delegates to `Post` with encoded body
- **`nextpas.core.http.intf`**: added `TFormFieldArray` type alias, `nextpas.core.http.form.base` dependency
- **Tests**: 1 new integration test (content-type + method verification), 135 client total / 0 leaks

**Phase 8 (2026-07-07): Form Encoding — Bidirectional Form Data**

- **`nextpas.core.http.form`**: added `EncodeUrlEncodedForm` (space-as-+, roundtrip-safe) and `EncodeMultipartFormData` (auto boundary generation, field+file support)
- **`nextpas.core.http` facade**: re-exported form types (`TFormField`, `TFormFieldArray`, `THttpFile`, `THttpFileArray`, `TMultipartFormData`) and encoding functions
- **Tests**: 8 new encoding tests (basic, empty, special chars, roundtrip for both URL-encoded and multipart), 16 total / 0 leaks

**Phase 7 (2026-07-07): GOAL_TREE Alignment**
- **TLS runtime proof**: marked as ✅ — `test_http_tls_real` (5 tests) proves self-signed cert, handshake, stream wrapper, H2 transport creation
- **H2 remaining hardening**: all items closed except documentation alignment

**Phase 6 (2026-07-07): Client Ergonomics — Options Method**
- **Options() convenience method**: `IHttpClient` now has full HTTP method coverage: Get, Post, Put, Delete, Patch, Head, Options
- **Client tests**: 133 → 134 (+1), all with 0 leaks

**Phase 5 (2026-07-07): TLS Warning Fix + Test Audit**
- **ErrorList warning**: `ValidateRequirements` in `tls.backend.selector.pas` — `TStringArray` local variable explicitly initialized to silence FPC managed-type warning across all HTTP test suites
- **Epoll backend audit**: confirmed 36 epoll test failures are pre-existing net-layer issues (main baseline identical), not HTTP regressions

**Phase 4 (2026-07-07): Static Graduation + Benchmark Truth**
- **Range requests**: RFC 7233 support — `bytes=start-end`, suffix (`bytes=-N`), open-ended (`bytes=N-`)
- **Conditional requests**: ETag + `If-None-Match` → 304, `Last-Modified` + `If-Modified-Since` → 304
- **Cache headers**: `Cache-Control: public, max-age=0, must-revalidate`
- **File downloads**: `ServeFileDownload()` with `Content-Disposition: attachment`
- **416 Range Not Satisfiable**: Invalid ranges return proper error with `Content-Range: bytes */size`
- **Benchmark CI**: `verify_benchmark_truth.sh` validates Rust/Go/Hyper/nextPas label correctness
- **Static tests**: 14 → 21 (+7), all with 0 leaks

### Recent Fixes (2026-07-06)

**Phase 1 (2026-07-06):**
- **P1-4 注册表冻结**: `GFrozen` 标志防止运行时注册表修改，`UnfreezeRegistry` 测试逃生口
- **P2-3 CONTRACT.md v2.0**: 完全重写匹配实际代码接口（IHttpClient/IHttpServer/THttpRequest/THttpResponse）
- **P2-11 HttpStatusText**: 未知状态码返回 `IntToStr(ACode)` 而非 `'Unknown'`
- **P2-13 ValidateValue**: 添加 RFC 9110 §5.5 规范注释

**Phase 2 (2026-07-06):**
- **P2-1 CORS 测试**: 5 个新测试（特定来源/拒绝/凭证+通配符/MaxAge/自定义方法头），覆盖率从 4→9
- **P2-7 ServeFileContent**: 错误响应添加 `Content-Type: text/plain` + 异常处理 → 500
- **P2-15 Logger**: `WriteLn` → `TLogger.Info` 结构化日志，新增 `LoggerMiddlewareWith` 重载

**Phase 3 (2026-07-06):**
- **H2 Client 测试覆盖**: 30→55 tests (+25)，覆盖连接池限制/错误处理/流控/协议边界/请求构造
- **H2 HPACK 测试覆盖**: 29→30 tests (+1)，多字节整数编码 roundtrip
- **Duplicate Host header**: Parser 检测重复 Host 头返回 400（RFC 9112 §6.2）
- **H2 Frame 测试**: 18→37 tests (+19)，覆盖 GOAWAY/WINDOW_UPDATE/RST_STREAM/PING/SETTINGS
- **H2 HPACK 测试**: 15→29 tests (+14)，覆盖编码器/动态表/Huffman/索引头

**Earlier Fixes:**
- **IPv4 字节序修复**: `platform_sockaddr_from_ipv4` 缺少 `htonl` 导致 `bind(99)` — 根因修复影响所有 TCP 服务器
- **Response parser pause**: `CbOnMessageComplete` 移除 `FParserType=ptRequest` 门控，response parser 在 keep-alive 连接上也暂停，防止同 TCP segment 多响应时错误池化连接
- **Same-read tail 检测**: `TH1ClientTransport.FPending` 跨 `ReadResponse` 调用保留未消费字节
- **Connection:close 响应**: response parser 的 `HPE_CLOSED_CONNECTION` 处理容忍额外数据

**测试**: 25 suites ~863 pass / 0 leak (36 epoll tests pre-existing failures on net layer)

## Map

```text
nextpas.core.http
├── G0: Module control, docs, and verification discipline         [active baseline]
├── G1: Stable public H1 surface                                 [mostly landed]
├── G2: Correctness, safety, lifecycle, and ownership proof      [advanced]
├── G3: API ergonomics and performance isolation                 [active]
├── G4: Protocol evolution seams (H2/H3 codec + registry + transport) [H2 transport landed, test hardening]
├── G5: Static/WebSocket graduation gates                        [helper-level stable]
└── G6: Cross-language benchmark truth and long-run positioning  [ongoing, not final]
```

## Stable Public Surface

These surfaces are already expected to behave like real framework APIs, not experimental helpers:

- `IHttpServer` / `THttpServer`
- `IHttpClient`
- `IHttpRouter`, `IHttpHandler`, `IHttpMiddleware`
- `IHttpHeaders`, `IHttpRequest`, `IHttpResponse`
- request/response helpers exposed through `nextpas.core.http`
- `ServeFile`, `ServeDir`
- `UpgradeWebSocket`, `IWebSocket`, `TWebSocketOptions`

Stability here means:

- public behavior is covered by focused tests
- nil/error/ownership edges are explicit
- transport/runtime details stay behind seams unless intentionally exposed
- helper additions should close real ergonomics gaps, not create a second overlapping API family

## Correctness And Safety Targets

HTTP is not done until these remain true:

- Every public API surface has direct focused coverage before it is called complete.
- Changed API behavior must have regression coverage and fresh heaptrc `0 unfreed memory blocks` evidence in the relevant focused gates.
- Request parsing, malformed framing, redirect semantics, timeout behavior, and response/body ownership must be explicitly defined and tested.
- Server runtime behavior must prefer precise wire-contract proof over synthetic “probably OK” reasoning.
- Error surfaces should fail fast at the API boundary when possible, instead of letting nil/access-violation behavior leak through transport internals.

Current strong areas:

- H1 parser and server malformed-input proof
- redirect semantics and response-body ownership
- server lifecycle shape
- runnable examples

Remaining pressure is mostly on keeping those guarantees coherent while the module evolves, not reopening broad undifferentiated correctness sweeps.

## Client Ergonomics Route

The client route should keep moving toward the best parts of Go/Rust ergonomics without copying names blindly.

Priority order:

1. request construction that makes method, URL, headers, body shape, and ownership obvious
2. response helpers that make read/release behavior obvious
3. redirect, timeout, and failure semantics that fail clearly at the public boundary
4. only then consider broader builder-style APIs

Already landed:

- URL string overloads for `NewRequest`
- string / bytes request body helpers
- string / bytes response body helpers
- response charset auto-detection (`HttpReadResponseBodyStringAuto` — UTF-8, Latin-1, fallback)
- explicit response body release helper
- tighter redirect method/body/header ownership semantics
- `PostForm` convenience for `application/x-www-form-urlencoded`
- form encoding (`EncodeUrlEncodedForm`, `EncodeMultipartFormData`)
- `PostJson`/`PutJson`/`PatchJson` convenience for `application/json`
- `Delete` body overloads (IReader, string, TBytes) — parity with Post/Put/Patch
- `DeleteJson` convenience for `application/json` DELETE requests
- `WithBasicAuth`/`WithBearerAuth` auth decorator (returns new `IHttpClient` with automatic `authorization` header)
- `WithHeader` generic header injection decorator (chains with auth: `WithBearerAuth(token).WithHeader('Accept', 'application/json')`)
- `WithTimeout`/`WithMaxRedirects`/`WithFollowRedirects` per-request options decorator (overrides client defaults for a single request)
- `IHttpRequestWithOptions` interface + `THttpRequestOptions` record for per-request option overrides
- `THttpRequestBuilder` fluent request builder (Header, BasicAuth, BearerAuth, ContentType, Body, QueryParam, Timeout, MaxRedirects, FollowRedirects, Build)
- `NewStreamingRequest` + `SendStreaming` streaming body ownership API (non-buffered IReader, explicit close-on-send contract, redirect replayability caveat)
- per-request timeout override at transport level (H1 transport checks `IHttpRequestWithOptions` to override `FOptions.Timeout`)
- `HttpEnsureSuccess` response status guard (raises EHttpError on non-2xx, returns response for chaining)

Still intentionally not claimed:

- (none currently)

Those can land later, but only after the contract shape is clear enough to stay stable.

## Server Runtime Route

The server route is not “make HTTP more async-looking.” The fixed direction is:

- keep the HTTP public surface synchronous and simple
- keep listener/runtime/backend ownership in `nextpas.core.net.server`
- keep H1/H2/H3 as protocol layers over common foundation seams
- let readiness-family and future completion-family runtimes share the same protocol-state ownership model

Current runtime truth:

- threaded is still the correctness baseline
- Linux `epoll` already has real poll-driven progress
- H1 successful response drain is reactor-owned on the poll path
- active + 1 queued response semantics already exist
- remaining runtime work is characterization and optimization, not a rewrite of the public model

High-risk runtime changes should stop for review if they broaden `net` / `async` / `platform` boundaries instead of clarifying them.

## Performance Evidence Route

Performance work should follow this order:

1. prove correctness and stable contracts first
2. isolate one cost center at a time
3. keep benchmark claims honest about what they do and do not prove
4. save broad ranking claims for later rounds

Current benchmark families already cover:

- server comparison runner
- Go `net/http` comparator
- Rust std-only comparator
- optional Hyper/Tokio comparator
- H1 parser microbenchmarks
- router dispatch
- header lookup
- H1 writer serialization
- H1 outbound drain
- full-chain keep-alive scenarios

Current isolation direction:

- parser adapter materialization
- lazy header access
- response writer serialization
- outbound drain
- writer plus outbound drain combination
- full-chain correlation with direct/router/middleware workload splits

What still matters most now is isolating remaining runtime/socket overhead and other non-parser/non-writer costs, not collecting more final benchmark tables too early.

## Protocol Evolution Gates

H2/H3 are important, but honesty matters more than placeholders.

Rules:

- No fake public API should imply that H3 already works.
- Future H3 work must preserve the same public HTTP contract unless there is a clear, documented reason to expand it.
- Rust or Go feature parity is not a reason to create empty abstractions.
- Current H2 transport policy is explicit: `http://` uses cleartext prior
  knowledge, `https://` requires negotiated ALPN `h2`, and HTTP/1.1
  `Upgrade: h2c` / `HTTP2-Settings` upgrade is not exposed.

H2 transport has landed as a complete implementation covering:

- **Frame codec** (RFC 9113): all 10 frame types, 13 error codes, frame validation, padded payload handling
- **HPACK** (RFC 7541): encoder/decoder, dynamic table with MRU cache, Huffman codec with 4-bit nibble decode, DecodeView zero-refcount path
- **Stream state machine**: 7-state machine, HEADERS/CONTINUATION assembly, trailer handling (pseudo-header/hop-by-hop forbidden), MaxHeaderListSize enforcement
- **Server session**: client preface validation, SETTINGS handshake, frame dispatch, per-stream request execution, MaxConcurrentStreams enforcement, GOAWAY with split last-stream tracking, poll-driven execution (ITcpServerPollDrivenSession)
- **Client transport**: synchronous RoundTrip, connection pool (MaxPoolSize-governed), stale pooled connection retry, server push rejection, PING/GOAWAY handling
- **TLS integration**: ALPN `h2` negotiation, SNI, session factory seam
- **RFC 9113 compliance**: HPACK table-size rules, MaxHeaderListSize (431/ENHANCE_YOUR_CALM), trailer section, GOAWAY last-stream tracking, MaxConcurrentStreams (REFUSED_STREAM)
- **Tests**: 181 focused tests across 7 suites + Go/Rust HPACK benchmark comparators

Design exclusions (by design, not gaps):
- h2c Upgrade path (cleartext H2 uses prior knowledge only)
- Server push (ENABLE_PUSH=0, PUSH_PROMISE → GOAWAY)
- CONNECT / WebSocket over H2 (future work)
- PRIORITY frame priority scheduling (parse, ignore — RFC permits)

Remaining H2 hardening:
- Test coverage vs h2-test-coverage-plan.md targets: client 55/55 (✅ closed), frame 37/35 (✅ closed), hpack 30/30 (✅ closed); session gap closed
- Real TLS runtime proof: ✅ `test_http_tls_real` (5 tests, self-signed cert + handshake + stream wrapper + H2 transport creation); 9 unfreed blocks are in openssl backend layer, not HTTP
- Documentation alignment (this document and ARCHITECTURE.md)

H3 is blocked on the QUIC module. Only `nextpas.core.tls.quic.crypto.pas` (QUIC v1 crypto primitives) exists; no QPACK/HTTP3 frame/stream source code.

## Static And WebSocket Graduation Criteria

Static and WebSocket helpers are intentionally helper-level public surfaces today.

They should stay that way unless there is a clear graduation contract:

- static serving should not grow into a broader service family until range, streaming, cache, and binary-file semantics are defined tightly enough to stay stable
- WebSocket should not grow new option families or extension negotiation APIs without a clear ownership and behavior story
- more negative-case testing is not itself progress unless it closes a real behavior gap

Current rule of thumb:

- helper-level behavior can keep tightening
- helper-to-subsystem graduation needs an explicit design decision

## Verification And Done Criteria

A slice is only done when all of these are true for its scope:

- RED or source-contract was observed first
- minimal implementation passed the relevant focused gate
- changed public surface has direct focused tests
- heaptrc-sensitive focused tests report `0 unfreed memory blocks`
- `git diff --check` passes
- `make hygiene` passes
- the slice is committed as one clear rollback unit

The module is not “done” because one slice is green. The overall HTTP goal remains active until the controller explicitly stops it or a requirement-by-requirement audit proves the whole target is complete.

## Current Highest-Value Slices

As of 2026-07-16, ordered execution queue:

1. **P1 — keep-alive request-tail contract decision** ✅ closed (INV-12)
2. **P2 — H2 facade end-to-end proof**
   - live `NewHttpClient/Server` with `Options.WithVersion(hvHttp2)`
   - keep h2c Upgrade / push / WS-over-H2 as explicit exclusions
3. **P3 — API surface audit (no expansion by default)**
   - `THttpRequestBuilder` is the recommended construction path
   - inventory deprecated `NewRequest` overloads; avoid a second overlapping API family
4. **P4 — runtime/socket cost isolation**
   - continue narrow benchmarks for non-parser/non-writer costs
   - no ranking claims without scoped caveats
5. **P5 — H3**
   - blocked on QUIC; only maintain registry/version seams

## Immediate Do-Not-Drift Rules

- Do not widen public API just to match a checklist from another ecosystem.
- Do not treat benchmark rows as durable performance truth without scoped caveats.
- Do not hide lower-layer design problems behind HTTP-only workarounds.
- Do not call exposed APIs complete without focused unit coverage and leak proof.
- Do not confuse “many tests” with “the right tests.”
