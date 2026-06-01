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
