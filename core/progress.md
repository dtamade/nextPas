# Progress Log: HTTP fixed-length keep-alive tail proof

## Session: 2026-06-03 HTTP fixed-length keep-alive tail

- **Status:** in_progress
- **Scope:** add parser/security focused proof that a keep-alive `Content-Length` request completes first and isolates its garbage tail as a follow-up malformed request.
- **Checklist:**
  - [x] Checked shared checkout dirtiness and limited this batch to HTTP paths.
  - [x] Re-read design conventions, HTTP inbox, API coverage matrix, and current control files.
  - [x] Confirmed the remaining gap is fixed-length keep-alive tail proof outside the existing server test.
  - [x] Added the new parser focused test for keep-alive `Content-Length` tail isolation.
  - [x] Added the new security focused test for raw-wire safe handling.
  - [x] Ran the first parser verification and recorded the result.
  - [x] Ran the first security verification and recorded the result.
  - [x] Determined this batch is direct GREEN coverage expansion, not a production bugfix.
  - [x] Updated HTTP route-tracking docs and batch control files.
  - [x] Run HTTP aggregate verification and diff hygiene.
  - [ ] Commit this batch with path-limited staging only.

## Baseline Evidence

- Shared checkout is dirty outside HTTP scope; broad git operations remain unsafe.
- Server already had a focused current-truth test for
  `Content-Length keep-alive garbage tail -> follow-up 400`.
- The missing layers were parser and security, which made the keep-alive tail contract less symmetric than the chunked side.

## Verification Evidence 2026-06-03 Focused First Run

| Check | Command | Result |
| --- | --- | --- |
| Parser focused suite | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | `46/46 passed`, heaptrc `0 unfreed memory blocks` |
| Security focused suite | `make -C tests/nextpas.core.http/test_http_security clean test` | `25/25 passed`, heaptrc `0 unfreed memory blocks` |
| HTTP aggregate entrypoint | `make TESTS_DIR=tests/nextpas.core.http test` | `All tests passed.`；`test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但 heaptrc 仍为 `0 unfreed memory blocks` |
| Git diff hygiene | `git diff --check -- <touched HTTP paths>` | clean |

## Notes

- Because the first runs were already GREEN, no production files were edited in this batch.
- The remaining work is procedural closeout: path-limited commit plus the round report.
