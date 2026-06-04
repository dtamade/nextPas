# Progress Log: expect interim-100 body-stall server contract proof

## Session

- **Scope:** 承接上一刀的 threaded 生产修复，把 `Expect: 100-continue`
  已发出 interim `100` 后 partial body stall 的 safe-close 语义补成
  `IHttpServer` public-contract focused proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side runtime truth` -> `Expect after interim 100 body-stall server proof`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 4 条 focused public-contract proofs：
  - threaded `Expect: fixed-length body stall closes safely after interim response`
  - threaded `Expect: chunked body stall closes safely after interim response`
  - epoll `Expect: fixed-length body stall closes safely after interim response`
  - epoll `Expect: chunked body stall closes safely after interim response`
- 这些 tests 直接锁住：
  - interim `100` 先发出
  - stall 后连接安全关闭
  - handler 不进入
  - 不重复 `100`
  - 不追加 synthetic `500`
  - 不再发 final status line
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步把同一条 truth 提升成 `test_http_server` + `test_http_security`
  双层证据，而不再只是 security 层 live proof。
- 本轮没有生产代码变更；focused gate 直接 GREEN，说明上一刀修复已在
  server 层 contract 上自然成立。

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `232/232 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀继续优先 request-side runtime / malformed 的真实小缺口。
- 更自然的后续候选：
  - 继续找 still-open 的 raw-wire malformed / timeout 邻接缺口
  - 或转向更高层 example / benchmark 之前仍未闭环的 HTTP public API seam
