# Progress Log: nextpas.core.http

## Session: 2026-06-01

### Phase 1: public contract audit and HTTP test baseline

- **Status:** complete
- **Scope:** inbox/plan/findings/progress plus stale H1 writer expectations.
- **Checklist:**
  - [x] Read active skill rules for planning, docs, and completion verification.
  - [x] Read `docs/design-conventions.md`.
  - [x] Checked Git state before edits.
  - [x] Confirmed current checkout is `main`, not a linked worktree.
  - [x] Re-read `docs/nextpas.core.http.inbox.md` and `task_plan.md`.
  - [x] Confirmed current HTTP baseline work and the remaining public API matrix gap.
  - [x] Updated the compact inbox/control map.
  - [x] Updated planning/findings/progress files for the current batch.
  - [x] Rerun the modified HTTP tests and capture fresh verification evidence.

## Verification Evidence

| Check                    | Command                                                                                    | Result                                         |
| ------------------------ | ------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| Design conventions read  | `sed -n '1,620p' docs/design-conventions.md`                                               | Completed                                      |
| Git safety state         | `git status --short --branch`                                                              | Shared checkout is dirty outside this batch    |
| Worktree detection       | `git rev-parse --git-dir`, `git rev-parse --git-common-dir`                                | Normal checkout on `main`, not linked worktree |
| HTTP source inventory    | `find src -maxdepth 1 -name 'nextpas.core.http*.pas'`                                      | 22 source units                                |
| HTTP test inventory      | `find tests/nextpas.core.http -mindepth 1 -maxdepth 1 -type d`                             | 19 test projects                               |
| HTTP benchmark inventory | `find benchmarks/nextpas.core.http* -mindepth 1 -maxdepth 1 -type d`                       | 7 benchmark projects                           |
| Markdown formatting      | `prettier --write docs/nextpas.core.http.inbox.md task_plan.md findings.md progress.md`    | Completed                                      |
| Whitespace check         | `git diff --check -- docs/nextpas.core.http.inbox.md task_plan.md findings.md progress.md` | No errors                                      |
| Focused H1 writer test   | `make -C tests/nextpas.core.http/test_http_h1writer clean test`                            | 10/10 passed, 0 unfreed memory blocks          |
| Focused integration test | `make -C tests/nextpas.core.http/test_http_integration clean test`                         | 18/18 passed, 0 unfreed memory blocks          |
| Full HTTP suite          | `make TESTS_DIR=tests/nextpas.core.http test`                                              | All tests passed; heaptrc zero leaks per test  |

## Notes

- The root planning files now describe the active HTTP module ownership work and the current API audit phase.
- The H1 writer contract is treated as chunked-by-default only when neither `Content-Length` nor `Transfer-Encoding` is preset.
- `test_http_smoke` still prints `True free heap : 261232 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`.

## Error Log

| Timestamp  | Error                                               | Attempt | Resolution                                                                                 |
| ---------- | --------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------ |
| 2026-06-01 | Stale root planning files from prior task           | 1       | Replaced with active HTTP plan/findings/progress                                           |
| 2026-06-01 | Shared checkout has unrelated dirty/untracked files | 1       | Kept this batch scoped to planning/control-map files                                       |
| 2026-06-01 | Stale H1 writer test expectations                   | 1       | Aligned the tests to current chunked framing                                               |
| 2026-06-02 | Tried to reuse `StrToBytes` in client tests         | 1       | Reverted to local test conversion; `StrToBytes` is private to `http.client` implementation |

## Session: 2026-06-02

### Phase 1: public API coverage matrix and client verb coverage

- **Status:** complete
- **Scope:** `IHttpClient` extra verb tests plus API coverage tracking docs.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, task plan, findings, and progress.
  - [x] Audited public HTTP source surfaces and current test registration points.
  - [x] Added `docs/http/API_COVERAGE.md`.
  - [x] Added focused tests for `IHttpClient.Put/Delete/Patch/Head`.
  - [x] Fixed test-only heaptrc leak caused by temporary response wrappers.
  - [x] Ran full HTTP suite after this batch.

## Verification Evidence 2026-06-02

| Check                   | Command                                                       | Result                                        |
| ----------------------- | ------------------------------------------------------------- | --------------------------------------------- |
| Git safety state        | `git status --short --branch`                                 | Shared checkout is dirty outside this batch   |
| Focused client test     | `make -C tests/nextpas.core.http/test_http_client clean test` | 13/13 passed, 0 unfreed memory blocks         |
| Full HTTP suite         | `make TESTS_DIR=tests/nextpas.core.http test`                 | All tests passed; heaptrc zero leaks per test |
| Design conventions read | `sed -n '1,1220p' docs/design-conventions.md`                 | Completed                                     |

## Notes 2026-06-02

- `IHttpClient` extra verbs were already implemented; this batch adds direct proof.
- The first client test run exposed a test helper leak: 13/13 passed but heaptrc reported 8 unfreed blocks. Root cause was temporary `THttpResponse` wrappers inside request handlers. Direct `IReader` reads fixed it.
- `test_http_smoke` still prints `True free heap : 261232 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`; this remains an observation rather than a failing leak signal.

## Review 2026-06-02

- `/codex` read-only review found no blocking issue.
- Review confirmed the new client verb tests use real local HTTP server/client paths rather than mocks.
- Review suggested avoiding an implementation-detail assertion for DELETE `Body=nil`; the test now asserts empty body behavior instead.
- Review reiterated the staging risk: do not use `git add .` in the dirty shared checkout.

## Session: 2026-06-02 transport contract shape

### Phase 1: transport public contract coverage

- **Status:** complete
- **Scope:** `IHttpTransport.RoundTrip` and `IHttpServerTransport.ServeConn` shape tests plus coverage docs.
- **Checklist:**
  - [x] Checked Git status before edits; HTTP files were clean, unrelated dirty/untracked files remain outside this batch.
  - [x] Re-read HTTP inbox, task plan, findings, progress, and API coverage matrix.
  - [x] Audited `http.intf`, facade re-exports, architecture docs, and source usage points.
  - [x] Confirmed transport interfaces are public shape seams only; no registry or injection owner exists yet.
  - [x] Added focused shape tests to `test_http_contract`.
  - [x] Ran full HTTP suite after this batch.

## Verification Evidence 2026-06-02 Transport

| Check                 | Command                                                         | Result                                        |
| --------------------- | --------------------------------------------------------------- | --------------------------------------------- |
| Git safety state      | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP         |
| Focused contract test | `make -C tests/nextpas.core.http/test_http_contract clean test` | 14/14 passed, 0 unfreed memory blocks         |
| Full HTTP suite       | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test |

## Notes 2026-06-02 Transport

- Transport tests deliberately avoid claiming production registry coverage.
- The current contract evidence is external implementability: mock classes can implement facade-exported `IHttpTransport` / `IHttpServerTransport`, receive request/handler parameters, and return or dispatch through the public HTTP types.

## Review 2026-06-02 Transport

- `/codex` read-only review found no blocking code issue.
- Review confirmed this batch proves public shape contract only, not facade-only smoke, registry, injection, protocol dispatch, or real TCP connection lifecycle.
- Review noted the full-suite evidence was still missing in its snapshot; mainline completed `make TESTS_DIR=tests/nextpas.core.http test` afterward and recorded the result above.
- Review reiterated the staging risk: the shared checkout has unrelated dirty/untracked files, so stage only the six owned HTTP files.

## Session: 2026-06-02 hijack lifecycle

### Phase 1: `IHttpHijacker` lifecycle and connection ownership

- **Status:** review
- **Scope:** facade alias, H1 writer hijack behavior, server ownership transfer after hijack.
- **Checklist:**
  - [x] Checked Git status before edits; HTTP target files were clean, unrelated dirty/untracked files remain outside this batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added facade-only `IHttpHijacker` alias coverage to `test_http_contract`.
  - [x] Added `TH1ResponseWriter.Hijack` focused tests to `test_http_h1writer`.
  - [x] Added server integration test proving hijack keeps the connection open for handler ownership.
  - [x] Verified RED: facade alias missing and server closed hijacked connections after handler return.
  - [x] Re-exported `IHttpHijacker` from `nextpas.core.http`.
  - [x] Made `HandleConnection` return server connection ownership and guarded thread cleanup.
  - [x] Ran focused GREEN tests with heaptrc proof.
  - [x] Run full HTTP suite.
  - [x] Complete local `/codex`-style review and final diff check.
  - [ ] Commit this batch.

## Verification Evidence 2026-06-02 Hijack

| Check                   | Command                                                         | Result                                                          |
| ----------------------- | --------------------------------------------------------------- | --------------------------------------------------------------- |
| Git safety state        | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files              |
| RED facade alias        | `make -C tests/nextpas.core.http/test_http_contract clean test` | Failed to compile: `Identifier not found "IHttpHijacker"`       |
| RED server ownership    | `make -C tests/nextpas.core.http/test_http_server clean test`   | Failed new hijack ownership assertion; heaptrc 0 unfreed blocks |
| Focused contract GREEN  | `make -C tests/nextpas.core.http/test_http_contract clean test` | 15/15 passed, 0 unfreed memory blocks                           |
| Focused H1 writer GREEN | `make -C tests/nextpas.core.http/test_http_h1writer clean test` | 12/12 passed, 0 unfreed memory blocks                           |
| Focused server GREEN    | `make -C tests/nextpas.core.http/test_http_server clean test`   | 20/20 passed, 0 unfreed memory blocks                           |
| Full HTTP suite         | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test                   |

## Notes 2026-06-02 Hijack

- `TH1ResponseWriter` already had the correct direct hijack behavior; this batch made that contract explicit.
- The production fix is in server connection lifecycle, not in websocket code.
- `HandleConnection` now reports whether the server still owns the connection. After hijack, cleanup does not `Shutdown` or `Close` the stream.
- `/codex`-style read-only review found no blocking issue.
- Review noted that the first server hijack test treated any read exception as open-connection evidence; the test now proves ownership directly by reading a client probe byte from the handler-held `ITcpStream` after handler return.

## Session: 2026-06-02 facade callback and overload smoke

### Phase 1: facade helper/public forwarding completion

- **Status:** complete
- **Scope:** `HandlerFunc` callback aliases and facade `NewHttpServer` / `NewHttpClient` overload smoke.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added failing contract tests for facade callback aliases and server/client overloads in `test_http_contract`.
  - [x] Verified RED: `nextpas.core.http.NewHttpServer(IHttpHandler)` was missing from the facade.
  - [x] Added `HandlerFunc` overloads for `THttpHandlerMethod` and `THttpHandlerProc` in middleware and facade.
  - [x] Added facade forwarding for `NewHttpServer(const AHandler: IHttpHandler)`.
  - [x] Ran focused GREEN contract tests with heaptrc proof.
  - [x] Ran full HTTP suite after the facade overload changes.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Facade

| Check                  | Command                                                         | Result                                                              |
| ---------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| Git safety state       | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files                  |
| RED contract compile   | `make -C tests/nextpas.core.http/test_http_contract clean test` | Failed to compile: wrong parameter count for facade `NewHttpServer` |
| Focused contract GREEN | `make -C tests/nextpas.core.http/test_http_contract clean test` | 19/19 passed, 0 unfreed memory blocks                               |
| Full HTTP suite        | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test                       |

## Notes 2026-06-02 Facade

- This batch tightened public helper ergonomics rather than changing runtime HTTP semantics.
- `nextpas.core.http.HandlerFunc` now has explicit overloads for closure, plain procedure, and object method entry points.
- `test_http_contract` now locks the callback alias path and both server/client facade overload families through direct `nextpas.core.http.*` calls.

## Review 2026-06-02 Facade

- `/codex`-style read-only review found no blocking issue.
- Review risk remains unchanged: do not use `git add .` in the shared checkout, because unrelated files are dirty or untracked outside this batch.
- Review follow-up: the next correctness slice should move to H1 writer boundary behavior before any benchmark work.

## Session: 2026-06-02 H1 writer boundaries

### Phase 1: H1 response writer flush/finalization contract

- **Status:** complete
- **Scope:** `TH1ResponseWriter` boundary behavior for pre-set `Transfer-Encoding`, explicit `Content-Length`, and chunked flush finalization.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added failing boundary tests in `test_http_h1writer`.
  - [x] Verified RED: writer still allowed `Write` after chunked `Flush`.
  - [x] Added focused coverage for pre-set `Transfer-Encoding` and explicit `Content-Length` flush path.
  - [x] Guarded `TH1ResponseWriter` against writes after chunked finalization.
  - [x] Ran focused GREEN writer tests with heaptrc proof.
  - [x] Ran full HTTP suite after the writer change.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 H1 Writer

| Check                | Command                                                         | Result                                                                                                          |
| -------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Git safety state     | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files                                                              |
| RED writer test      | `make -C tests/nextpas.core.http/test_http_h1writer clean test` | 14/15 passed; `Write after chunked flush raises` failed; heaptrc non-0 because the failing test aborted cleanup |
| Focused writer GREEN | `make -C tests/nextpas.core.http/test_http_h1writer clean test` | 15/15 passed, 0 unfreed memory blocks                                                                           |
| Full HTTP suite      | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test                                                                   |

## Notes 2026-06-02 H1 Writer

- This batch tightened the H1 response writer state machine without changing server/client public API shape.
- Chunked responses now become finalized after the terminal chunk is flushed, and later body writes raise `EHttpError`.
- Pre-set `Transfer-Encoding` remains caller-owned, and explicit `Content-Length` responses do not emit a chunk terminator on `Flush`.

## Review 2026-06-02 H1 Writer

- `/codex`-style read-only review found no blocking issue.
- Review risk remains unchanged: do not use `git add .` in the shared checkout, because unrelated files are dirty or untracked outside this batch.
- Review follow-up: the next correctness slice should move to client chunked-response and close-delimited response coverage.

## Session: 2026-06-02 client response framing coverage

### Phase 1: client chunked and close-delimited body proof

- **Status:** complete
- **Scope:** focused `IHttpClient` response-body coverage for chunked transfer and EOF-delimited framing.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added focused chunked-response and close-delimited-response tests in `test_http_client`.
  - [x] Verified the existing implementation already satisfies both contracts; no production code change was required in this batch.
  - [x] Ran focused GREEN client tests with heaptrc proof.
  - [x] Ran full HTTP suite after the coverage change.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Client Framing

| Check               | Command                                                       | Result                                             |
| ------------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| Git safety state    | `git status --short --branch`                                 | Shared checkout is dirty outside HTTP target files |
| Focused client test | `make -C tests/nextpas.core.http/test_http_client clean test` | 15/15 passed, 0 unfreed memory blocks              |
| Full HTTP suite     | `make TESTS_DIR=tests/nextpas.core.http test`                 | All tests passed; heaptrc zero leaks per test      |

## Notes 2026-06-02 Client Framing

- This batch is coverage-only by design: the new tests passed on the first run, so no production bugfix was needed.
- The chunked-response proof uses the normal `THttpServer` path to validate dechunked client body reads through real server/client I/O.
- The close-delimited proof uses a raw socket response without `Content-Length`, which exercises the parser EOF completion path used by `THttpClient.ReadResponse`.

## Review 2026-06-02 Client Framing

- `/codex`-style read-only review found no blocking issue.
- Review risk remains unchanged: do not use `git add .` in the shared checkout, because unrelated files are dirty or untracked outside this batch.
- Review follow-up: the next local HTTP slice should either add direct `TChunkedWriter` focused tests or audit close-delimited response reuse semantics in the client pooling path.
