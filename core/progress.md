# Progress Log: http server expect list-membership semantics

## Session

- **Scope:** 给 `Expect` request-side contract 补齐 list-membership 语义：duplicate `100-continue` 仍应触发 interim `100 Continue`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `Expect semantics tightening` -> `duplicate 100-continue list-membership`

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

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  把 `RequestExpectsContinue` 从 exact-equals 判定改成 comma-separated
  list-membership 扫描。
- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 duplicate `100-continue` threaded / epoll focused tests，并先拿到 RED，
  再验证修复后 GREEN。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 `Expect` list-membership current truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `194/194 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 更合理的两个方向是：
  - 继续把 `Expect` 做成更完整的 request-side characterization
  - 或回到 malformed/runtime 边角，再挑一个独立状态分支收口
