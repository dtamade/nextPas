# Progress Log: nextpas.core.http epoll follow-up tail differential proof

## Session

- **Scope:** 扩大 Linux `epoll` backend 的 HTTP server differential proof。
- **Status:** in_progress

## Current state

- 已确认上轮 `epoll` 已补到 trailer-complete 路径，本轮继续补 plain `Content-Length` /
  plain chunked follow-up tail differential proof。
- 共享 worktree 仍是脏的；本轮继续只碰 HTTP 相关 tests 和最小控制面。
- 当前新增 tests 已证明 `epoll` phase-1 backend 不会破坏 plain `Content-Length` /
  plain chunked follow-up tail 的 malformed follow-up 核心契约。

## Completed work

- 新增 `epoll` focused tests：
  - keep-alive `Content-Length` garbage tail -> follow-up `400`
  - keep-alive `Content-Length` truncated follow-up request line -> follow-up `400`
  - keep-alive `Content-Length` truncated follow-up headers -> follow-up `400`
  - keep-alive plain chunked garbage tail -> follow-up `400`
  - keep-alive plain chunked truncated follow-up request line -> follow-up `400`
  - keep-alive plain chunked truncated follow-up headers -> follow-up `400`
- fresh 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `104/104 passed`
    - heaptrc `0 unfreed memory blocks`

## Next step

- 中文收尾报告里明确：
  - 当前 `epoll` 仍是 phase-1 accept-evented backend
  - 这轮新增的是 plain `Content-Length` / plain chunked malformed follow-up differential proof
  - 下一步应从 H1 correctness 横向复制转向更高价值的 backpressure / phase-2 runtime / cross-backend architecture work
