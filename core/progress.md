# Progress Log: http trailer-complete same-write pipelining raw-wire proof

## Session

- **Scope:** 给 `test_http_security` 补 chunked trailer-complete same-write pipelined next request 的 raw-wire proof，并补 Linux `epoll` live variant。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `keep-alive request-tail contract` -> `chunked trailer-complete same-write pipelining proof`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1294)
  新增了一个窄 helper，用来证明 trailer-complete chunked request 与同包第二个 request 能稳定拆分为两条独立 `200` 响应。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1330)
  现在新增两条 security raw-wire proof：
  - threaded: chunked trailer same-write pipeline
  - epoll: chunked trailer same-write pipeline
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md:18)
  已同步 trailer-complete same-write pipelining truth，并把下一步路线重新收敛到剩余 malformed grammar 边角或 request-tail contract 余下缺口筛查。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `71/71 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先回到仍缺分类的 malformed trailer/chunk truncation 相邻子类
- 或者先做一次 request-tail contract 矩阵筛查，确认 security 层是否还缺别的 raw-wire truth
