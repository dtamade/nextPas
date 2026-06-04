# Progress Log: http security keep-alive partial follow-up headers raw-wire bridge

## Session

- **Scope:** 把 `Content-Length` 与 plain `chunked` 的 keep-alive partial follow-up headers 从 half-close safe-handling 收成更具体的 raw-wire bridge proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `keep-alive request-tail contract` -> `Content-Length/chunked partial follow-up headers raw-wire bridge`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增四条 focused proofs：
  - threaded / epoll `Content-Length` partial follow-up headers can complete later
  - threaded / epoll plain `chunked` partial follow-up headers can complete later
  - 四条路径都锁住首个请求先完成、follow-up headers 后续可补齐成合法第二请求
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已把 `test_http_security` 的 `Content-Length` / plain `chunked` partial follow-up headers 从 half-close safe-handling 提升成 raw-wire bridge proof。
- 本轮没有生产代码变更；focused gate 直接 GREEN，说明这是 current truth 收口，而不是修复。

## Verification

- `make -C tests/nextpas.core.http/test_http_security test`
  - `128/128 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 最自然的后续是继续补：
  - 转去仍未分类完的 malformed/runtime 邻接缺口
  - 或重新审视 request-tail contract 还有没有更高价值的非平铺空档
