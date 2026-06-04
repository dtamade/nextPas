# Progress Log: expect interim-100 zero-progress idle-timeout proof

## Session

- **Scope:** 承接上一刀的 `Expect: 100-continue` partial-body stall coverage，
  补齐 `interim 100` 已发出后 body 完全零进展的 idle-timeout 相邻 truth，
  用 `test_http_security` + `test_http_server` 双层 focused proof 收口。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side runtime truth` -> `Expect after interim 100 zero-progress idle-timeout`

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

- [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增 4 条 raw-wire focused proofs：
  - threaded `Expect: fixed-length zero body progress idle-timeout`
  - threaded `Expect: chunked zero body progress idle-timeout`
  - epoll `Expect: fixed-length zero body progress idle-timeout`
  - epoll `Expect: chunked zero body progress idle-timeout`
- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 4 条 focused public-contract proofs：
  - threaded `Expect: fixed-length zero body progress idle-timeout closes after interim response`
  - threaded `Expect: chunked zero body progress idle-timeout closes after interim response`
  - epoll `Expect: fixed-length zero body progress idle-timeout closes after interim response`
  - epoll `Expect: chunked zero body progress idle-timeout closes after interim response`
- 这些 tests 直接锁住：
  - interim `100` 先发出
  - zero-progress stall 后连接安全关闭
  - handler 不进入
  - 不重复 `100`
  - 不追加 synthetic `500`
  - 不再发 final status line
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步把 `Expect after interim 100 + zero-progress idle-timeout`
  纳入 `test_http_server` + `test_http_security` 双层证据。
- 本轮没有生产代码变更；focused gate 直接 GREEN，说明上一刀修复已在
  当前生产代码上自然成立，这轮只是 coverage-expansion。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `206/206 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `236/236 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀继续优先 request-side runtime / malformed 的真实小缺口。
- 更自然的后续候选：
  - 继续找 still-open 的 raw-wire malformed / timeout 邻接缺口
  - 暂不继续机械平铺 `Expect` 同型 case
