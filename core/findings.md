# Findings: nextpas.core.http module ownership

## Project Rules Read

- `docs/design-conventions.md` is the binding style and architecture guide for `nextpas.core`.
- `http` is an L3 framework module and may depend only on L0-L2 modules.
- Module shape is responsibility-driven: facade/base/intf/ffi/implementation files exist only when their responsibilities are real.
- Facades must explicitly re-export public types and forward functions because FPC does not auto re-export.
- Public APIs should use small interfaces, COM reference counting for builders/handlers where appropriate, default exception propagation, and `TryXxx` only when branch-friendly failure handling is useful.
- Tests are independent `.lpr` projects under `tests/nextpas.core.<module>/...`; benchmarks are independent projects under `benchmarks/nextpas.core.<module>/...`.

## HTTP Architecture Findings

- `docs/http/ARCHITECTURE.md` positions HTTP as a unified facade plus shared application layer plus isolated protocol implementations.
- Current long-term architecture expects H1 first, then H2 after TLS/ALPN readiness, then H3 after QUIC readiness.
- Current source tree has implemented H1 parser/writer/scan/fast units, middleware presets, static serving, websocket upgrade, server/client skeletons, and public facade forwarding.
- Existing HTTP source inventory contains 24 `src/nextpas.core.http*.pas` units:
  - facade/contracts: `http`, `http.base`, `http.intf`
  - shared application layer: headers, URL, message, router, middleware, server, client, static, websocket
  - H1 protocol layer: llhttp, parser, writer, chunked, scan, fast
  - preset middleware: CORS, logger, recovery, timeout
- Existing HTTP tests contain 21 focused test projects covering base, client, contract, H1 parser/scan/writer/fast/chunked, headers, integration, message, middleware(s), registry, router, security, server, smoke, static, URL, websocket.
- Existing benchmark projects cover H1 parser, headers, router, server, full chain, generic HTTP, and protocol comparison.

## Baseline Verification Findings

- `TH1ResponseWriter` currently defaults to chunked transfer when neither `Content-Length` nor `Transfer-Encoding` is preset.
- `nextpas.core.http.server` only adds `Connection: close` when the server itself plans to close the connection.
- The stale expectations in `test_http_h1writer` and `test_http_integration` were test-only drift, not a production regression.
- The updated tests now assert chunked framing and explicit flush behavior.

## API Coverage Findings

- First public coverage matrix is now in `docs/http/API_COVERAGE.md`.
- `IHttpClient.Put`, `Delete`, `Patch`, and `Head` now have direct focused tests in `test_http_client`.
- The extra verb tests use real local HTTP server/client paths and assert method dispatch, body/header forwarding, and HEAD response header access.
- A test-only leak appeared when request bodies were read by wrapping `AReq.Body` in temporary `THttpResponse` objects; replacing that with direct `IReader` reads restored heaptrc to zero.
- The `Delete` test now asserts the public behavior, namely method dispatch, zero content length, and empty body, instead of depending on the internal `Body=nil` representation.
- `nextpas.core.http.impl.h1.pas` now exists and owns the default H1 client/server transport behavior that used to live inside `http.client` / `http.server`.
- `THttpClient` now acts as an orchestrator over `IHttpTransport`, while `THttpServer` owns only listener/accept/thread orchestration over `IHttpServerTransport`.
- `nextpas.core.http` / `http.client` / `http.server` now expose explicit transport injection overloads, and `test_http_contract` proves both client and server runtime delegation through those seams.
- `THttpClientOptions` / `THttpServerOptions` now live in `http.base`, which keeps them as public carrier types and preserves a clean downward dependency direction for the registry layer.
- `nextpas.core.http.impl.registry.pas` now exists and centralizes default version-to-transport resolution for both client and server constructors.
- The current built-in registry mapping is `hvHttp10` / `hvHttp11` -> H1, with `hvHttp11` as the default client/server version.
- `test_http_registry` now proves the missing-version error path plus the default-constructor resolution path for both `THttpClient` and `THttpServer`.
- `IHttpHijacker` was defined in `http.intf` but was missing from the facade aliases; `test_http_contract` now proves it can be consumed through `nextpas.core.http`.
- `TH1ResponseWriter.Hijack` already raised `EHttpError` without a connection and returned the underlying connection when present; focused tests now lock that behavior.
- `THttpServer` previously stopped the request loop after hijack but still closed the connection in thread cleanup; `test_http_server` now proves ownership transfers to the handler after hijack.
- `nextpas.core.http` now explicitly forwards `HandlerFunc` overloads for `THttpHandlerMethod` and `THttpHandlerProc`, plus the default `NewHttpServer(const AHandler: IHttpHandler)` overload.
- `test_http_contract` now gives direct facade smoke for callback aliases and server/client overloads, instead of leaving those entry points as inferred coverage only.
- `TH1ResponseWriter` now preserves caller-supplied `Transfer-Encoding`, does not append a terminal chunk on explicit `Content-Length` responses, and raises `EHttpError` if code tries to write after chunked finalization.
- `THttpClient.ReadResponse` already handled both chunked and close-delimited response bodies; this batch added focused proof rather than changing production code.
- The new client coverage uses two distinct paths: a normal `THttpServer` chunked response and a raw socket response without `Content-Length`, proving EOF-delimited body completion through the parser `Finish` path.
- `THttpClient` previously decided pool reuse only from `Connection: close`, which was too weak for close-delimited responses and HTTP/1.0 semantics.
- `IH1Parser` now exposes `ShouldKeepAlive`, and the implementation derives that answer from parsed version, framing headers, status code, and `Connection` semantics.
- `THttpClient` pooling now trusts parser-derived keep-alive semantics, so EOF-delimited responses and HTTP/1.0 responses without `Connection: keep-alive` are no longer returned to the pool.
- `TChunkedWriter` now has direct focused tests in `test_http_h1chunked` for single/multiple chunks, zero-length writes, hex chunk lengths, terminal chunk idempotence, and write-after-finalization behavior.
- `TChunkedWriter` previously allowed writes after the terminal chunk had been flushed; it now raises `EHttpError` at the helper level, not only through `TH1ResponseWriter`.
- `TH1Parser.Finish` previously treated any parsed response with a status line as EOF-complete, even when a `Content-Length` body was truncated.
- `test_http_h1parser` now locks that fixed-length truncation at EOF is an error, not a successful completion path.
- `test_http_client` now proves the public client raises `EHttpError` on truncated fixed-length responses instead of returning a partial body.
- EOF completion is now limited to true close-delimited responses (no `Transfer-Encoding`, no `Content-Length`, and status codes that may legally carry a body).
- `test_http_h1parser` 现在也直接证明了 request-side chunked 行为：正常 chunked body 解码、invalid chunk-size 触发 parser error、truncated chunked body 在 `Finish` 时失败。
- `test_http_h1parser` 现在还直接证明了 chunk data 后缺少 CRLF 会触发 parser error，而不会被误判为完整请求。
- `test_http_h1parser` 现在也直接锁定了 `Content-Length` 与 `Transfer-Encoding: chunked` 冲突的两种顺序：`CL -> TE` 与 `TE -> CL` 都会触发 parser error，而不是被宽松接受。
- `test_http_server` 现在证明了 handler 读取到的是 decoded chunked request body，而不是原始 chunk framing。
- 同一组 server focused tests 也证明了 `THttpServerOptions.MaxBodySize` 会对 chunked inbound traffic 的跨 chunk 累加超限生效。
- `test_http_server` 现在也直接锁定 raw-wire malformed chunked request 语义：invalid chunk-size 返回 `400`，truncated EOF 则返回 `400` 或安全关闭，而且这两类异常 chunk 都不会进入 handler。
- `test_http_server` 现在还直接锁定了 `CL -> TE` / `TE -> CL` 冲突都返回 `400`，并且都不会进入 handler。
- 这一轮没有生产代码改动；新增 focused tests 直接通过，说明现有实现已经满足这一组 inbound chunked request 契约。
- `test_http_security` 现在不再把 `CL+TE` conflict 放在 broad safe-handling 桶里，而是明确断言 `400`；同时也新增了 malformed chunk extension -> `400` 的 raw-wire proof。
- 新增 RED parser/server proof 已确认合法 chunked trailer 之前会污染普通 `Headers`：`Trailer: X-Auth-Context` 声明头和实际 trailer 字段会一起进入同一个 `IHttpHeaders` 视图。
- `nextpas.core.http.impl.h1.parser` 现在在 `CbOnHeaderValueComplete` 里读取 llhttp `F_TRAILING` 标志；普通 header 阶段仍写入 `FHeaders`，trailer 阶段则忽略写入，因此当前窄契约变成“保留初始 `Trailer:` 声明头，但实际 trailer 字段不进入普通请求头”。

## Git and Collaboration Findings

- Current directory is `/home/dtamade/projects/nextPas/core`.
- `git_dir` equals `git_common`; this is the normal `main` checkout, not a linked worktree.
- The shared checkout has unrelated modified and untracked files outside this batch.
- Safe rule for this batch: touch only HTTP takeover planning/control-map files and do not stage unrelated work.
- Commit `c9b2d26c` accidentally included unrelated compiler and root-doc files because the repo index already contained staged paths outside `core/`.
- Safe recovery in this shared checkout is a narrow follow-up cleanup commit that restores only those unrelated paths to `HEAD~1`; avoid `reset`, `rebase`, `commit --amend`, or any other history rewrite.

## Gaps to Audit Next

- Keep the matrix current as public APIs change.
- Hijack exception-after-takeover and websocket upgrade ownership regressions are useful later hardening tests.
- Direct `TChunkedWriter` focused coverage is now complete for writer-side framing invariants; malformed inbound chunk parsing belongs in parser/security tests.
- Benchmark baselines exist but should not drive changes until contract coverage and correctness gates are green.
- Same-client regression coverage for “EOF-delimited first response, reusable second connection afterward” is still optional; the core reuse decision is now locked at parser level.
- Future H2/H3 work should extend the landed internal registry instead of reintroducing version-default logic inside facade/client/server constructors.
- The next parser-security gap is now more specific: malformed/oversize trailer behavior 还没有 focused proof，且是否需要独立 public trailer API 仍待决策；当前先维持“ignore trailer fields, preserve Trailer declaration header”的窄契约。

## Communication Cadence Adopted

- Start every HTTP batch by showing an explicit task checklist.
- Keep `docs/nextpas.core.http.inbox.md` short and user-facing; keep `task_plan.md`, `findings.md`, and `progress.md` detailed enough for execution recovery.
- End every batch with what changed, verification evidence, retrospective, next plan, and git status/commit state.

## Review Findings

- `/codex` read-only review found no blocking issue in this batch.
- Review risk to enforce at commit time: stage only the owned HTTP planning/test files, because the shared checkout contains unrelated dirty and untracked files.
- Review follow-up: coverage matrix is surface/group level; later API-completion work should refine it toward method/function-level coverage where necessary.
