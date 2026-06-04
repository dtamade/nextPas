# Progress Log: http server expect plus transfer-coding rejection ordering

## Session

- **Scope:** 给 `Expect` request-side contract 补齐 transfer-coding error ordering：异常编码必须先拒绝，不能误发 interim `100`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `Expect semantics tightening` -> `expect plus transfer-coding rejection ordering`

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
  新增四条 focused proofs：
  - threaded / epoll `Expect + Transfer-Encoding: gzip, chunked`
  - threaded / epoll `Expect + Transfer-Encoding: chunked, gzip`
  - 两组都直接返回最终 `501/400`
  - wire 上不出现 interim `100`
  - handler 不会被调用
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 `Expect + transfer-coding` current truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `210/210 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 更合理的两个方向是：
  - 继续把 `Expect` 做成更完整的 request-side characterization
  - 或回到 malformed/runtime 边角，再挑一个独立状态分支收口
