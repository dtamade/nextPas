# Task Plan: nextpas.core.http module ownership

## Goal

Drive `nextpas.core.http` toward a production-grade Free Pascal HTTP framework module: clear public contracts, H1 correctness first, complete interface tests, heaptrc-clean verification, and benchmark-backed performance after correctness stabilizes.

## Current Phase

Phase 2/3 correctness hardening: internal registry is landed, truncated fixed-length response EOF rejection is now locked, and the next slice narrows to malformed chunked request/body parser-security boundaries.

## Active Batch Checklist

- [x] Re-read HTTP inbox, API coverage, architecture, findings, progress, and design conventions.
- [x] Inspect Git status and confirm unrelated dirty files remain outside this HTTP batch.
- [x] Add RED parser/client tests for truncated `Content-Length` responses at EOF.
- [x] Verify RED: parser `Finish` and public client both accepted truncated fixed-length responses.
- [x] Tighten `src/nextpas.core.http.impl.h1.parser.pas` so only true close-delimited responses may complete at EOF.
- [x] Re-run focused parser/client tests with heaptrc evidence.
- [x] Re-run the full HTTP suite after the parser fix.
- [x] Update inbox, coverage matrix, findings, and progress for this batch.
- [x] Commit only the owned HTTP files for this truncation batch.

## Quality Gates

| Gate                    | Rule                                                                                                                                                                    |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Public API completion   | A public HTTP API is not complete until its exposed contract has focused unit tests covering success, boundary, and error paths.                                        |
| Leak verification       | Tests that validate changed API surfaces must run with heaptrc or the repo-equivalent leak check and report zero unfreed memory blocks.                                 |
| Scope discipline        | Benchmarking is last-round work for a slice; first make interfaces correct, tested, and maintainable.                                                                   |
| Architecture discipline | Follow `docs/design-conventions.md`: facade/base/intf/implementation responsibilities, downward dependencies, interface-first boundaries, and no fake four-piece files. |
| Git safety              | Work in small, reviewable commits and never stage or rewrite unrelated work in the shared tree.                                                                         |

## Goal Tree Link

- Compact HTTP control map: `docs/nextpas.core.http.inbox.md`
- Architecture reference: `docs/http/ARCHITECTURE.md`
- User-facing overview: `docs/http/README.md`

## Near-Term Route

1. **Phase 0: Takeover and baseline map**
   - [x] Establish the active plan and compact inbox/control map.
   - [x] Record current source/test/benchmark inventory.
   - [x] Prepare the planning-only batch for a narrow commit.

2. **Phase 1: Public contract audit**
   - [x] Build an API matrix for facade, `http.base`, `http.intf`, headers, URL, message, router, middleware, server, client, static, websocket, and H1 parser/writer/scan/fast units.
   - [x] Map major public type/function/method groups to existing focused tests.
   - [x] Identify missing coverage before implementation changes.
   - [x] Run the HTTP test suite to establish the current baseline.

3. **Phase 2: H1 correctness hardening**
   - [ ] Prioritize RFC-critical request/response parsing, serialization, chunked transfer, limits, keep-alive, upgrade, and malformed-input behavior.
   - [ ] Add failing tests before fixes.
   - [ ] Keep parser/writer contracts explicit and small.

4. **Phase 3: Server/client integration hardening**
   - [ ] Verify handler dispatch, response writer state machine, error boundaries, connection lifecycle, shutdown, client request behavior, and default transport resolution.
   - [ ] Keep network-facing errors non-leaky and deterministic.

5. **Phase 4: Documentation and examples**
   - [ ] Update `docs/http/README.md` and architecture docs after contracts settle.
   - [ ] Add examples only after the tested API shape is stable.

6. **Phase 5: Benchmark and optimization**
   - [ ] Run HTTP benchmarks after correctness gates are green.
   - [ ] Compare with FPC RTL equivalents where meaningful and with Go/Rust public baselines for HTTP parser/router/server paths.
   - [ ] Consider SIMD fast paths only behind proven tests and benchmarks.

## Current Inventory

| Surface                 | Current count or files                              |
| ----------------------- | --------------------------------------------------- |
| HTTP source units       | 24 units under `src/nextpas.core.http*.pas`         |
| HTTP test projects      | 21 directories under `tests/nextpas.core.http/`     |
| HTTP benchmark projects | 7 directories under `benchmarks/nextpas.core.http*` |
| Existing docs           | `docs/http/README.md`, `docs/http/ARCHITECTURE.md`  |

## Decisions

| Decision                                         | Rationale                                                                                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Keep the H1 writer chunked-by-default contract   | Matches current implementation and server tests; do not force a production change without a tested reason.                                 |
| Keep benchmark work after correctness            | User explicitly asked to benchmark in the final round after interfaces are fixed and complete.                                             |
| Commit only owned HTTP planning/test files       | Current shared checkout has unrelated dirty/untracked files outside this HTTP batch.                                                       |
| Treat empty DELETE body by behavior              | The public contract is no request body and zero content length, not the internal `Body=nil` representation.                                |
| Treat transport coverage as shape-only           | `IHttpTransport` / `IHttpServerTransport` have no registry or injection owner yet, so this batch proves external implementability only.    |
| Transfer hijacked connection ownership           | After `IHttpHijacker.Hijack`, the HTTP server loop and thread cleanup must not write, shutdown, or close the connection.                   |
| Expose callback aliases through helpers          | `THttpHandlerMethod` / `THttpHandlerProc` should be usable from public helper APIs, not only exist as type aliases.                        |
| Finalize chunked responses on flush              | Once a chunked response has emitted the terminal chunk, further body writes must raise `EHttpError` instead of corrupting the stream.      |
| Treat coverage-only batches honestly             | If new focused tests pass immediately, record the batch as proof/coverage expansion rather than inventing a production bugfix.             |
| Prefer follow-up cleanup over history rewrite    | In the shared checkout, undo accidental mixed commits with narrow follow-up commits rather than `reset`, `rebase`, or commit rewriting.    |
| Let parser own response reuse semantics          | Client pooling should depend on parsed HTTP version/framing/connection semantics, not only on a `Connection: close` header guess.          |
| Keep chunk finalization enforced at helper level | `TChunkedWriter` itself must reject writes after the terminal chunk, so all callers share the same framing invariant.                      |
| Land injection seam before registry              | Make transport ownership explicit in public factories first, then build `impl.registry` on top of a real client/server seam.               |
| Keep registry internal for now                   | The current need is centralized default resolution, not a public protocol-plugin surface before H2/H3 transports exist.                    |
| Keep public options in `http.base`               | They are public carrier types and keeping them in `base` preserves clean downward dependency direction for the registry layer.             |
| Reject truncated fixed-length responses at EOF   | A response with declared `Content-Length` is not close-delimited; accepting EOF there would return corrupt bodies and mislead reuse logic. |

## Errors Encountered

| Error                                                          | Attempt | Resolution                                                                                                           |
| -------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| Root planning files described an old parser TryParse task      | 1       | Replaced them with the active HTTP ownership plan while preserving old content in git history.                       |
| Shared checkout is dirty with unrelated files                  | 1       | Limited this batch to tracked planning/docs files owned by the HTTP takeover.                                        |
| Server closed hijacked connections after handler return        | 1       | Added RED integration test, then made `HandleConnection` return server ownership state.                              |
| Facade lacked `NewHttpServer(IHttpHandler)` overload           | 1       | Added RED contract test, then forwarded the default overload from `nextpas.core.http`.                               |
| Chunked writer accepted writes after final flush               | 1       | Added RED writer test, then tracked chunked finalization in `TH1ResponseWriter.Write/Flush`.                         |
| Client response framing lacked focused proof                   | 1       | Added chunked and close-delimited client tests; both passed immediately, so no production fix was required.          |
| Coverage commit accidentally included unrelated files          | 1       | Restore only the unrelated compiler/root-doc paths in a follow-up commit; keep the HTTP coverage commit intact.      |
| Client reuse semantics lacked framing-aware proof              | 1       | Added RED parser tests, then routed pooling decisions through parser-derived keep-alive semantics.                   |
| Chunked helper allowed writes after terminal chunk             | 1       | Added focused `test_http_h1chunked`, then made `TChunkedWriter.Write` raise after `Flush`.                           |
| Transport interfaces had no production owner                   | 1       | Added RED facade injection tests, then extracted default H1 transport ownership into `impl.h1` and public overloads. |
| Public option carriers lived in client/server units            | 1       | Moved them into `http.base`, which let the new registry depend downward instead of upward on client/server.          |
| Response parser treated truncated fixed-length EOF as complete | 1       | Added RED parser/client tests, then limited EOF completion to true close-delimited responses only.                   |
