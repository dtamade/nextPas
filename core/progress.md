# Progress Log: nextpas.core.http epoll trailer-complete differential proof

## Session

- **Scope:** 扩大 Linux `epoll` backend 的 HTTP server differential proof。
- **Status:** in_progress

## Current state

- 已确认上轮 `epoll` 已补到 keep-alive / fixed-chunked pipelining / hijack，本轮继续补
  chunked trailer-complete follow-up differential proof。
- 共享 worktree 仍是脏的；本轮继续只碰 HTTP 相关 tests 和最小控制面。
- 当前新增 tests 已证明 `epoll` phase-1 backend 不会破坏 chunked trailer-complete 的
  malformed follow-up / pipelined-next-request / deferred completion 核心契约。

## Completed work

- 在 [test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr:73) 复用了 `StartServerWithOptions`，新增 `StartEpollServer` helper。
- 新增 `epoll` focused tests：
  - chunked trailer-complete keep-alive garbage tail -> follow-up `400`
  - chunked trailer-complete keep-alive truncated follow-up request line -> follow-up `400`
  - chunked trailer-complete keep-alive truncated follow-up headers -> follow-up `400`
  - chunked trailer-complete same-write pipelining
  - chunked trailer-complete partial follow-up request line can complete later
- fresh 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `98/98 passed`
    - heaptrc `0 unfreed memory blocks`

## Next step

- path-limited staging / commit。
- 中文收尾报告里明确：
  - 当前 `epoll` 仍是 phase-1 accept-evented backend
  - 这轮新增的是 chunked trailer-complete malformed follow-up / pipelining / delayed completion differential proof
  - 下一步应视价值继续补 plain follow-up tail differential variants，再推进 backpressure / phase-2 runtime
