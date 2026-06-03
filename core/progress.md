# Progress Log: nextpas.core.http epoll backend differential proof

## Session

- **Scope:** 扩大 Linux `epoll` backend 的 HTTP server differential proof。
- **Status:** in_progress

## Current state

- 已确认上轮 `epoll` 只在 `test_http_server` 有 simple GET smoke，本轮继续补 backend-differential proof。
- 共享 worktree 仍是脏的；本轮继续只碰 HTTP 相关 tests 和最小控制面。
- 当前新增 tests 已证明 `epoll` phase-1 backend 不会破坏 keep-alive / pipelining / hijack 核心契约。

## Completed work

- 在 [test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr:73) 复用了 `StartServerWithOptions`，新增 `StartEpollServer` helper。
- 新增 `epoll` focused tests：
  - keep-alive two requests
  - fixed-length same-write pipelining
  - chunked same-write pipelining
  - hijack ownership
  - hijack exception path
- fresh 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `93/93 passed`
    - heaptrc `0 unfreed memory blocks`

## Next step

- 更新覆盖矩阵与控制文件，确认本轮证据进入文档真相。
- path-limited staging / commit。
- 中文收尾报告里明确：
  - 当前 `epoll` 仍是 phase-1 accept-evented backend
  - 这轮新增的是 keep-alive / pipelining / hijack differential proof
  - 下一步应继续补 trailer-complete / malformed tail / backpressure，再推进 phase-2 runtime
