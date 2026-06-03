# Progress Log: HTTP truncated chunk-size line proof

## Session: 2026-06-03 HTTP chunk-size line EOF truncation

- **Status:** complete
- **Scope:** add parser/server/security focused proof that a truncated chunk-size line is rejected at EOF / peer half-close with explicit `400` semantics.
- **Checklist:**
  - [x] Checked shared checkout dirtiness and limited this batch to HTTP paths.
  - [x] Re-read design conventions, HTTP inbox, API coverage matrix, and current control files.
  - [x] Confirmed the remaining malformed-chunk gap is chunk-size line EOF truncation.
  - [x] Added the new parser focused test for chunk-size line EOF truncation.
  - [x] Added the new server focused test for chunk-size line EOF truncation.
  - [x] Added the new security focused test for chunk-size line EOF truncation.
  - [x] Ran the first parser verification and recorded the result.
  - [x] Ran the first server verification and recorded the result.
  - [x] Ran the first security verification and recorded the result.
  - [x] Determined this batch is direct GREEN coverage expansion, not a production bugfix.
  - [x] Updated HTTP route-tracking docs and batch control files.
  - [x] Run HTTP aggregate verification and diff hygiene.
  - [x] Commit this batch with path-limited staging only.

## Baseline Evidence

- Shared checkout is dirty outside HTTP scope; broad git operations remain unsafe.
- Existing chunked truncation proof only directly covered chunk-data truncation, not the chunk-size line grammar itself.
- Server/security EOF handling for partial requests was already strong enough that this batch was expected to be either RED proof or direct GREEN closeout.

## Verification Evidence 2026-06-03 Focused First Run

| Check | Command | Result |
| --- | --- | --- |
| Parser focused suite | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | `47/47 passed`, heaptrc `0 unfreed memory blocks` |
| Server focused suite | `make -C tests/nextpas.core.http/test_http_server clean test` | `50/50 passed`, heaptrc `0 unfreed memory blocks` |
| Security focused suite | `make -C tests/nextpas.core.http/test_http_security clean test` | `26/26 passed`, heaptrc `0 unfreed memory blocks` |
| HTTP aggregate entrypoint | `make TESTS_DIR=tests/nextpas.core.http test` | `All tests passed.`；`test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但 heaptrc 仍为 `0 unfreed memory blocks` |
| Git diff hygiene | `git diff --check -- <touched HTTP paths>` | clean |

## Notes

- Because the first runs were already GREEN, no production files were edited in this batch.
- This batch closed as coverage expansion for truncated chunk-size line truth, not as a production fix.
