# Task Plan: nextpas.core.http module ownership

## Goal

Drive `nextpas.core.http` toward a production-grade Free Pascal HTTP framework module: clear public contracts, H1 correctness first, complete interface tests, heaptrc-clean verification, and benchmark-backed performance after correctness stabilizes.

## Current Phase

Phase 1: public contract audit and HTTP test baseline.

## Active Batch Checklist

- [x] Re-read `task_plan.md` and `docs/nextpas.core.http.inbox.md`.
- [x] Inspect Git status and confirm unrelated dirty files remain outside this batch.
- [x] Extract HTTP public API surfaces from `src/nextpas.core.http*.pas`.
- [x] Build the public API coverage matrix.
- [x] Run existing `tests/nextpas.core.http/*` baseline.
- [x] Record pass/fail and heaptrc evidence.
- [x] Refresh docs and progress after rerunning the two changed tests.
- [x] Commit the documentation/baseline batch.
- [x] Add focused coverage for `IHttpClient.Put/Delete/Patch/Head`.
- [x] Run full HTTP suite after client coverage changes.
- [x] Update inbox, findings, and progress for this coverage batch.
- [x] Commit this coverage batch.
- [x] Audit `IHttpTransport` / `IHttpServerTransport` public contract shape.
- [x] Add focused shape coverage for `RoundTrip` and `ServeConn`.
- [x] Run full HTTP suite after transport contract coverage changes.
- [x] Update inbox, coverage matrix, findings, and progress for this coverage batch.
- [x] Commit this coverage batch.

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
   - [ ] Verify handler dispatch, response writer state machine, error boundaries, connection lifecycle, shutdown, and client request behavior.
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
| HTTP source units       | 22 units under `src/nextpas.core.http*.pas`         |
| HTTP test projects      | 19 directories under `tests/nextpas.core.http/`     |
| HTTP benchmark projects | 7 directories under `benchmarks/nextpas.core.http*` |
| Existing docs           | `docs/http/README.md`, `docs/http/ARCHITECTURE.md`  |

## Decisions

| Decision                                       | Rationale                                                                                                                               |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Keep the H1 writer chunked-by-default contract | Matches current implementation and server tests; do not force a production change without a tested reason.                              |
| Keep benchmark work after correctness          | User explicitly asked to benchmark in the final round after interfaces are fixed and complete.                                          |
| Commit only owned HTTP planning/test files     | Current shared checkout has unrelated dirty/untracked files outside this HTTP batch.                                                    |
| Treat empty DELETE body by behavior            | The public contract is no request body and zero content length, not the internal `Body=nil` representation.                             |
| Treat transport coverage as shape-only         | `IHttpTransport` / `IHttpServerTransport` have no registry or injection owner yet, so this batch proves external implementability only. |

## Errors Encountered

| Error                                                     | Attempt | Resolution                                                                                     |
| --------------------------------------------------------- | ------- | ---------------------------------------------------------------------------------------------- |
| Root planning files described an old parser TryParse task | 1       | Replaced them with the active HTTP ownership plan while preserving old content in git history. |
| Shared checkout is dirty with unrelated files             | 1       | Limited this batch to tracked planning/docs files owned by the HTTP takeover.                  |
