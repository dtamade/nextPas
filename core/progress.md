# Progress Log: HTTP chunked trailer keep-alive tail proof

## Session: 2026-06-03 HTTP chunked trailer keep-alive tail

- **Status:** completed
- **Scope:** add parser/server/security focused proof that a chunked request with a
  complete trailer section still finishes the first request cleanly when same-connection
  bytes continue as garbage tail, partial follow-up request line, or partial follow-up
  headers; the tail then becomes follow-up `400`.
- **Checklist:**
  - [x] Checked shared checkout dirtiness and limited this batch to HTTP paths.
  - [x] Re-read design conventions, API coverage matrix, and current control files.
  - [x] Confirmed the next gap is `chunked + trailer + keep-alive tail` isolation after a complete trailer section.
  - [x] Added the new parser focused tests for trailer-complete garbage tail / partial follow-up line / partial follow-up headers.
  - [x] Added the new server focused tests for the same three trailer-complete keep-alive variants.
  - [x] Added the new security focused tests for the same three trailer-complete keep-alive variants.
  - [x] Ran the first parser verification and recorded the result.
  - [x] Ran the first server verification and recorded the result.
  - [x] Ran the first security verification and recorded the result.
  - [x] Determined this batch is direct GREEN coverage expansion, not a production bugfix.
  - [x] Updated API coverage and batch control files.
  - [x] Ran HTTP aggregate verification and diff hygiene.
  - [ ] Commit this batch with path-limited staging only.

## Baseline Evidence

- Shared checkout is still dirty outside HTTP scope; broad git operations remain unsafe.
- Existing plain chunked keep-alive truth already covered:
  `garbage tail`, `partial follow-up request line`, `partial follow-up headers`,
  and valid pipelined next request isolation.
- Existing trailer truth already covered:
  trailer declaration is preserved, trailer fields stay out of ordinary headers,
  and malformed / EOF-truncated trailer grammar is rejected.
- The missing intersection was the trailer-complete keep-alive tail boundary:
  `...0\r\nX-Test: value\r\n\r\ngarbage`,
  `...0\r\nX-Test: value\r\n\r\nGET /next HTTP/1.1`,
  `...0\r\nX-Test: value\r\n\r\nGET /next HTTP/1.1\r\nHost: localhost\r\n`.

## Verification Evidence 2026-06-03 Focused First Run

| Check | Command | Result |
| --- | --- | --- |
| Parser focused suite | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | `76/76 passed`, heaptrc `0 unfreed memory blocks` |
| Server focused suite | `make -C tests/nextpas.core.http/test_http_server clean test` | `79/79 passed`, heaptrc `0 unfreed memory blocks` |
| Security focused suite | `make -C tests/nextpas.core.http/test_http_security clean test` | `55/55 passed`, heaptrc `0 unfreed memory blocks` |

## Verification Evidence 2026-06-03 HTTP Aggregate

| Check | Command | Result |
| --- | --- | --- |
| HTTP aggregate | `make TESTS_DIR=tests/nextpas.core.http test` | `All tests passed`; `test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但各套件 heaptrc 仍为 `0 unfreed memory blocks` |

## Notes

- Because the first runs were already GREEN, no production files were edited in this batch.
- `git diff --check` 已对本批路径通过。
