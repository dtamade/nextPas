# Progress Log: http security oversize-trailer backpressure proof

## Session

- **Scope:** 给 malformed chunked raw-wire security 补齐 `oversize trailer -> 431` 的 live direct-error backpressure focused proof，并校正一处旧测试 truth。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `malformed chunked live hardening` -> `oversize-trailer backpressure 431`

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
  新增两条 `chunked oversize trailer -> 431` live direct-error backpressure proof：
  - threaded backend
  - epoll backend
- 同文件还把既有 `Request line too long` 断言校正到当前真实语义：
  - 超长 request-line 现在允许命中 `MaxHeaderSize` 共用的 `431` 路径
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 `431` live direct-error backpressure 与 long-request-line current truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_security test`
  - `122/122 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 更合理的两个方向是：
  - 再挑一个仍未分类完的 malformed/runtime 边角收口
  - 或回到 `Expect` 组合/优先级语义，补 request-side characterization
