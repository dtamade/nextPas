# Progress Log: http content-length truncated follow-up headers epoll raw-wire proof

## Session

- **Scope:** 做一次 parser/server/security 矩阵筛查，然后给 `test_http_security` 补 `Content-Length` truncated follow-up headers 的 epoll raw-wire proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `keep-alive request-tail contract` -> `content-length truncated follow-up headers epoll proof`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1017)
  把 `Content-Length` truncated follow-up headers 的 threaded 断言抽成可复用 helper，避免 epoll 版本再拷一份 safe-handling 逻辑。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1453)
  新增 `Content-Length keep-alive truncated follow-up headers safe handling with epoll backend` raw-wire proof，锁定首个 `200 / echo:5` 之后 follow-up EOF truncation 仍回 `400`。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md:18)
  已同步 security 层新的 epoll request-tail truth，并把下一步路线收敛为“只挑剩余真实 gap”，不再做整片同型 parity 搬运。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `76/76 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先只挑一个剩余 request-tail sibling gap，或回到仍缺分类的 malformed trailer/chunk truncation 相邻子类
- 如果下一次矩阵筛查只剩机械 parity case，就停止扩 security，回到更高价值的 correctness 边界
