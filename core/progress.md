# Progress Log: http chunk truncation epoll live parity proofs

## Session

- **Scope:** 做一次 parser/server/security 矩阵筛查，然后把 `test_http_security` 里 chunk truncation 的 epoll live parity gap 成批补齐。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `malformed chunked/trailer boundary` -> `chunk truncation epoll live parity proofs`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  把 threaded 版 chunk truncation case 抽成可复用 helper，避免 epoll 版本继续复制 12 份近似 raw-wire EOF 断言。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增 12 条 epoll raw-wire proof，补齐 chunk truncation 这一整族在 live backend 上的 `400` 语义。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 security 层新的 chunk truncation epoll live truth，并把下一步路线继续收敛到“只挑真正还缺的 malformed raw-wire gap”。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `106/106 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先重新筛查是否还有更高价值的 malformed raw-wire 边界
- 如果下一次矩阵筛查只剩机械 parity case，就停止扩 security，回到更高价值的 correctness 边界
