# Progress Log: http server expect-continue chunked ingress coverage

## Session

- **Scope:** 给 `Expect` request-side contract 补齐 chunked ingress live proof：interim `100`、decoded body、以及 after-interim `413`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `Expect semantics tightening` -> `expect-continue chunked ingress`

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
  新增四条 `Expect + chunked` focused proofs：
  - threaded / epoll `Expect + chunked` interim `100` + decoded body
  - threaded / epoll `Expect + chunked` cross-chunk `MaxBodySize` after-interim `413`
  同时把 oversize case 从错误的固定 literal 改成动态构造真实 700-byte chunks。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 `Expect + chunked` current truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `200/200 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 更合理的两个方向是：
  - 继续把 `Expect` 做成更完整的 request-side characterization
  - 或回到 malformed/runtime 边角，再挑一个独立状态分支收口
