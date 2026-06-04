# Progress Log: http server no-length expect-continue guard proof

## Session

- **Scope:** 给 `Expect` request-side contract 补齐 no-body guard 的相邻分支：完全不声明 body 时不应误发 interim `100`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `Expect semantics tightening` -> `no-length expect-continue guard`

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

- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  抽出共享 bodyless `Expect` live helper，并新增两条 focused proofs：
  - threaded / epoll no-length `Expect: 100-continue`
  - 直接 final `200`，且 wire 上不出现 interim `100`
  - handler 正常被调用，并读到空 body
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 no-length bodyless `Expect` current truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `204/204 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 更合理的两个方向是：
  - 继续把 `Expect` 做成更完整的 request-side characterization
  - 或回到 malformed/runtime 边角，再挑一个独立状态分支收口
