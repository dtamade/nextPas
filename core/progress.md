# Progress Log: expect interim-100 body-stall idle-timeout truth

## Session

- **Scope:** 锁住 `Expect: 100-continue` 已发出 interim `100` 后，
  partial request body stall 的 request-side `IdleTimeout` 语义；要求
  threaded / Linux `epoll` 两条 live path 都安全关闭，且不追加 synthetic
  `500`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side runtime truth` -> `Expect after interim 100 body-stall idle-timeout`

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
  新增 4 条 focused live proofs：
  - threaded `Expect fixed-length partial body idle-timeout closes after interim 100`
  - threaded `Expect chunked partial body idle-timeout closes after interim 100`
  - epoll `Expect fixed-length partial body idle-timeout closes after interim 100`
  - epoll `Expect chunked partial body idle-timeout closes after interim 100`
- 首轮 focused gate 拿到真实 RED：
  - `202 total, 200 passed, 2 failed`
  - 失败只在 threaded 两条，失败断言是 `stalled body does not append synthetic 500`
  - epoll 两条直接通过
- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  做了最小生产修复：
  - 新增 `IsRequestReadFailure`
  - `TH1ServerConnectionState.Run` 的 outer `except` 对 request-side read
    failure 直接安全关闭，不再误补 final `500`
- 根因已锁定：
  - threaded live path 用的是 blocking `TTcpStream.Read`
  - socket timeout 在这里会落成 `ENetworkError('tcp read failed (...)')`
  - 旧 whole-run `Run` outer except 把这种 ingress 读失败误判成内部错误
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步把 `Expect after interim 100 + body stall` safe-close / no synthetic
  `500` 记入 `IHttpServer` coverage truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `202/202 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀继续优先 request-side runtime / malformed 的真实小缺口，不回到大面积 parity 平铺。
- 更自然的后续候选：
  - 看 `test_http_server` 是否还缺同主题 public-contract focused proof
  - 或继续找 still-open 的 raw-wire malformed / timeout 邻接缺口
