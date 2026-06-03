# Progress Log: HTTP keep-alive chunked partial follow-up proof

## Session: 2026-06-03 HTTP keep-alive chunked partial follow-up

- **Status:** completed
- **Scope:** add parser/server/security focused proof that chunked keep-alive requests with
  partial follow-up request line / partial follow-up headers still complete the first request,
  then reject the follow-up with explicit `400` after peer half-close.
- **Checklist:**
  - [x] Checked shared checkout dirtiness and limited this batch to HTTP paths.
  - [x] Re-read design conventions, API coverage matrix, and current control files.
  - [x] Confirmed the next keep-alive chunked gap is partial follow-up request line / headers truth.
  - [x] Added the new parser focused tests for chunked partial follow-up request line and partial follow-up headers.
  - [x] Added the new server focused tests for the same two chunked keep-alive follow-up variants.
  - [x] Added the new security focused tests for the same two chunked keep-alive follow-up variants.
  - [x] Ran the first parser verification and recorded the result.
  - [x] Ran the first server verification and recorded the result.
  - [x] Ran the first security verification and recorded the result.
  - [x] Determined this batch is direct GREEN coverage expansion, not a production bugfix.
  - [x] Updated HTTP route-tracking docs and batch control files.
  - [x] Run HTTP aggregate verification and diff hygiene.
  - [x] Commit this batch with path-limited staging only.

## Baseline Evidence

- Shared checkout is dirty outside HTTP scope; broad git operations remain unsafe.
- Existing chunked keep-alive truth already covered:
  `Connection: close` extra bytes -> explicit `400`,
  keep-alive garbage tail -> first request completes then follow-up `400`,
  valid pipelined next request -> first request isolation.
- The missing boundaries were the two in-between keep-alive follow-up subclasses:
  `...0\r\n\r\nGET /next HTTP/1.1`
  and
  `...0\r\n\r\nGET /next HTTP/1.1\r\nHost: localhost\r\n`.

## Verification Evidence 2026-06-03 Focused First Run

| Check | Command | Result |
| --- | --- | --- |
| Parser focused suite | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | `73/73 passed`, heaptrc `0 unfreed memory blocks` |
| Server focused suite | `make -C tests/nextpas.core.http/test_http_server clean test` | `76/76 passed`, heaptrc `0 unfreed memory blocks` |
| Security focused suite | `make -C tests/nextpas.core.http/test_http_security clean test` | `52/52 passed`, heaptrc `0 unfreed memory blocks` |

## Verification Evidence 2026-06-03 HTTP Aggregate

| Check | Command | Result |
| --- | --- | --- |
| HTTP aggregate | `make TESTS_DIR=tests/nextpas.core.http test` | `All tests passed`; `test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但各套件 heaptrc 仍为 `0 unfreed memory blocks` |

## Notes

- Because the first runs were already GREEN, no production files were edited in this batch.
- `git diff --check` 已对本批路径通过。
- 本批已按 path-limited 提交。
