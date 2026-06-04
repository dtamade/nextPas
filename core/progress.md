# Progress Log: http live epoll malformed chunked security parity

## Session

- **Scope:** 给 `test_http_security` 补一组 Linux `epoll` live malformed chunked representative parity proof。
- **Status:** verified

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:195)
  新增了一个窄测试 helper，用来按 options 启动 live security server 并断言 raw-wire status。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1583)
  现在新增 4 条 Linux `epoll` backend representative malformed chunked live parity proof：
  - unsupported transfer-coding before chunked -> `501`
  - invalid chunk size -> `400`
  - missing chunk-data CRLF -> `400`
  - truncated trailer section CR EOF -> `400`
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md:18)
  已同步 epoll live malformed chunked parity 结论，并把下一步路线收敛到更高信息增益的 `431` / safe-close trailer-budget truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `66/66 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 如果继续补 live backend parity，优先加 `epoll` 下 oversize trailer 的 `431` / safe-close proof
- 否则就回到仍缺信息增益的 malformed raw-wire security 边角，而不是继续复制同型 `400` case
