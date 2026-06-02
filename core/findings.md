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
- Existing HTTP source inventory contains 22 `src/nextpas.core.http*.pas` units:
  - facade/contracts: `http`, `http.base`, `http.intf`
  - shared application layer: headers, URL, message, router, middleware, server, client, static, websocket
  - H1 protocol layer: llhttp, parser, writer, chunked, scan, fast
  - preset middleware: CORS, logger, recovery, timeout
- Existing HTTP tests contain 19 focused test projects covering base, client, contract, H1 parser/scan/writer/fast, headers, integration, message, middleware(s), router, security, server, smoke, static, URL, websocket.
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
- `IHttpTransport` and `IHttpServerTransport` are currently exposed only as public interfaces and facade aliases; there is no implemented registry, protocol owner, or client/server injection path yet.
- Transport tests in `test_http_contract` therefore cover contract shape and external implementability, not production protocol dispatch.
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

## Git and Collaboration Findings

- Current directory is `/home/dtamade/projects/nextPas/core`.
- `git_dir` equals `git_common`; this is the normal `main` checkout, not a linked worktree.
- The shared checkout has unrelated modified and untracked files outside this batch.
- Safe rule for this batch: touch only HTTP takeover planning/control-map files and do not stage unrelated work.
- Commit `c9b2d26c` accidentally included unrelated compiler and root-doc files because the repo index already contained staged paths outside `core/`.
- Safe recovery in this shared checkout is a narrow follow-up cleanup commit that restores only those unrelated paths to `HEAD~1`; avoid `reset`, `rebase`, `commit --amend`, or any other history rewrite.

## Gaps to Audit Next

- `docs/http/ARCHITECTURE.md` mentions planned units such as `impl.registry`, `impl.h1.conn`, and H2/H3 units that are not present in the current source inventory.
- Keep the matrix current as public APIs change.
- Hijack exception-after-takeover and websocket upgrade ownership regressions are useful later hardening tests.
- Transport registry / protocol ownership still needs design before H2/H3 expansion or pluggable client/server transports.
- Direct `TChunkedWriter` focused coverage is now complete for writer-side framing invariants; malformed inbound chunk parsing belongs in parser/security tests.
- Benchmark baselines exist but should not drive changes until contract coverage and correctness gates are green.
- Same-client regression coverage for “EOF-delimited first response, reusable second connection afterward” is still optional; the core reuse decision is now locked at parser level.

## Communication Cadence Adopted

- Start every HTTP batch by showing an explicit task checklist.
- Keep `docs/nextpas.core.http.inbox.md` short and user-facing; keep `task_plan.md`, `findings.md`, and `progress.md` detailed enough for execution recovery.
- End every batch with what changed, verification evidence, retrospective, next plan, and git status/commit state.

## Review Findings

- `/codex` read-only review found no blocking issue in this batch.
- Review risk to enforce at commit time: stage only the owned HTTP planning/test files, because the shared checkout contains unrelated dirty and untracked files.
- Review follow-up: coverage matrix is surface/group level; later API-completion work should refine it toward method/function-level coverage where necessary.
