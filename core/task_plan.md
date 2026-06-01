# Task Plan: nextpas.core.http module ownership

## Goal

Drive `nextpas.core.http` toward a production-grade Free Pascal HTTP framework module: clear public contracts, H1 correctness first, complete interface tests, heaptrc-clean verification, and benchmark-backed performance after correctness stabilizes.

## Current Phase

Phase 0: module takeover and control map setup.

## Active Batch Checklist

- [x] Read `docs/design-conventions.md`.
- [x] Inspect current Git/worktree safety state before editing.
- [x] Review existing HTTP architecture docs, facade, base, and interface units.
- [x] Inventory current HTTP source, tests, and benchmark surfaces.
- [x] Create a compact HTTP inbox/control map for current work and route tracking.
- [x] Replace stale root planning files with the active HTTP ownership plan.
- [x] Prepare only this planning/control-map batch after review and hygiene checks.

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
   - [ ] Build an API matrix for facade, `http.base`, `http.intf`, headers, URL, message, router, middleware, server, client, static, websocket, and H1 parser/writer/scan/fast units.
   - [ ] Map every public type/function/method to existing focused tests.
   - [ ] Identify missing coverage before implementation changes.
   - [ ] Run the narrow existing HTTP test suites to establish the current baseline.

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

| Decision                                      | Rationale                                                                                                                          |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Treat this round as planning/control-map only | User asked to change communication and work cadence first; code changes need a clear `/plan` and target map before implementation. |
| Keep benchmark work after correctness         | User explicitly asked to benchmark in the final round after interfaces are fixed and complete.                                     |
| Commit only owned planning files              | Current shared checkout has unrelated dirty/untracked files outside this HTTP takeover batch.                                      |

## Errors Encountered

| Error                                                     | Attempt | Resolution                                                                                     |
| --------------------------------------------------------- | ------- | ---------------------------------------------------------------------------------------------- |
| Root planning files described an old parser TryParse task | 1       | Replaced them with the active HTTP ownership plan while preserving old content in git history. |
| Shared checkout is dirty with unrelated files             | 1       | Limited this batch to tracked planning/docs files owned by the HTTP takeover.                  |
