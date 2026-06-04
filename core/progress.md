# Progress Log: http trailer-complete partial-next-line raw-wire bridge proof

## Session

- **Scope:** 给 `test_http_security` 补 chunked trailer-complete partial follow-up request-line bridge truth，并补 Linux `epoll` live variant。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `keep-alive request-tail contract` -> `chunked trailer-complete partial-next-line bridge proof`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1239)
  新增了一个窄 helper，用来证明 trailer-complete chunked request 后的半截 follow-up request line 可以在后续字节补全后继续合法完成。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1288)
  现在新增两条 security raw-wire proof：
  - threaded: chunked trailer partial-next-line can complete later
  - epoll: chunked trailer partial-next-line can complete later
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md:18)
  已同步 trailer-complete partial-next-line bridge truth，并把下一步路线收敛到 trailer same-write pipelining 或剩余 malformed grammar 边角。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `69/69 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先看 trailer-complete same-write pipelined next request 的 security raw-wire proof
- 如果不走 request-tail contract，就回到仍缺分类的 malformed trailer/chunk truncation 相邻子类
