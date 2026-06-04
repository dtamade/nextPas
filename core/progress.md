# Progress Log: http epoll malformed chunked live parity

## Session

- **Scope:** 给 Linux `epoll` backend 补上两条 malformed chunked live raw-wire `400` proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `raw-wire malformed chunked security` -> `epoll live parity tightening`

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
  新增两条 focused live raw-wire proof：
  `Chunked extra bytes after close -> 400 with epoll backend`、
  `Malformed trailer field -> 400 with epoll backend`。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步这两条 malformed chunked `epoll` live parity 说明。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `120/120 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀不要继续平铺相同类型的 backend parity。
- 更合理的两个方向是：
  - 转向真正还没分类完的 runtime / malformed 边角
  - 或审视 `3/6 H1 正确性加固` 的阶段收口条件，准备衔接更高层的 server/base 架构演进
