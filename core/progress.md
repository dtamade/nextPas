# Progress Log: HTTP chunked pipelined request isolation proof

## Session: 2026-06-03 HTTP chunked first-request pipelining

- **Status:** complete
- **Scope:** land focused parser/server proof that a chunked first request remains isolated when a second request arrives in the same read/write.
- **Checklist:**
  - [x] Checked shared checkout dirtiness and limited this batch to HTTP paths.
  - [x] Re-read design conventions, HTTP inbox, API coverage matrix, and current WIP diff.
  - [x] Ran the first parser verification for the new chunked same-read pipelining test.
  - [x] Ran the first server verification for the new chunked same-write pipelining test.
  - [x] Determined this batch is direct GREEN coverage expansion, not a production bugfix.
  - [x] Updated HTTP route-tracking docs and batch control files.
  - [x] Run HTTP aggregate verification and diff hygiene.
  - [x] Commit this batch with path-limited staging only.

## Baseline Evidence

- Shared checkout is dirty outside HTTP scope; broad git operations remain unsafe.
- Current HTTP baseline before this batch was already green after commit `3ebd5e9d`
  (`test(http): cover keepalive chunked tail handling`).
- The only uncommitted HTTP work carried into this session was two new focused tests:
  - parser: chunked first request followed by pipelined next request in the same buffer
  - server: chunked first request followed by a second request in the same write

## Verification Evidence 2026-06-03 Focused First Run

| Check | Command | Result |
| --- | --- | --- |
| Parser focused suite | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | `45/45 passed`, heaptrc `0 unfreed memory blocks` |
| Server focused suite | `make -C tests/nextpas.core.http/test_http_server clean test` | `49/49 passed`, heaptrc `0 unfreed memory blocks` |
| HTTP aggregate entrypoint | `make TESTS_DIR=tests/nextpas.core.http test` | `All tests passed.`；`test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但 heaptrc 仍为 `0 unfreed memory blocks` |
| Git diff hygiene | `git diff --check -- <touched HTTP paths>` | clean |

## Notes

- Because the first runs were already GREEN, no production files were edited in this batch.
- This batch closed as coverage expansion for chunked first-request pipelining truth, not as a production fix.
