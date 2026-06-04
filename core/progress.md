# Progress Log: http chunked epoll request-tail safety proofs

## Session

- **Scope:** 做一次 parser/server/security 矩阵筛查，然后把 `test_http_security` 里 chunked epoll request-tail 剩余 sibling gap 成批补齐。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `keep-alive request-tail contract` -> `chunked epoll request-tail safety proofs`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  把 threaded 版 plain chunked / trailer-complete chunked 的 `garbage tail` 与 `truncated follow-up request line` 断言抽成可复用 helper，避免 epoll 版本再复制同型 safe-handling 逻辑。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增四条 epoll raw-wire proof：
  - `Chunked keep-alive garbage tail safe handling with epoll backend`
  - `Chunked keep-alive truncated follow-up request line safe handling with epoll backend`
  - `Chunked trailer keep-alive garbage tail safe handling with epoll backend`
  - `Chunked trailer keep-alive truncated follow-up request line safe handling with epoll backend`
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 security 层新的 chunked epoll request-tail truth，并把下一步路线继续收敛到“离开已基本收口的 parity 面”。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `82/82 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先回到仍缺分类的 malformed trailer/chunk truncation 相邻子类
- 如果下一次矩阵筛查只剩机械 parity case，就停止扩 security，回到更高价值的 correctness 边界
