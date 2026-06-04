# Progress Log: http direct-error live safe-close proof

## Session

- **Scope:** 把 `standalone direct-error` 的 real-socket safe-close truth 补到 `test_http_security`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `runtime truth tightening` -> `direct-error live safe-close proof`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  引入最小 socket-tuning transport seam 与 real-socket helpers，让 security suite 可以稳定做 backpressure 尝试而不动生产代码。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增 representative live proof：
  - threaded：malformed direct `400`、unsupported transfer-coding direct `501`
  - epoll：malformed direct `400`、unsupported transfer-coding direct `501`
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 direct-error real-socket safe-close envelope 的新证据。

## Verification

- `make -C tests/nextpas.core.http/test_http_security test`
  - `115/115 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先做一次高价值收口判断：
  - facade helper boundary audit
  - 或 HTTP Server correctness 当前阶段是否已经接近可收口边界
- 如果 correctness 只剩低价值 duplication，就应停止横向补 case，转到更高层路线图
