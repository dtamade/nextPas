# Progress Log: nextpas.core.http h1 response short-write hardening

## Session

- **Scope:** 收紧 H1 response write 在 short-write / zero-progress 下的 correctness。
- **Status:** in_progress

## Current state

- 已确认 `epoll` follow-up tail 这条线阶段性收口，本轮把焦点转到
  `TH1ResponseWriter` / `TChunkedWriter` 的 partial-write seam。
- 共享 worktree 仍是脏的；本轮继续只碰 HTTP 相关 tests 和最小控制面。
- 当前新增 RED tests 已证明旧实现会在 short-write 下静默截断 response framing / body；
  GREEN 后已确认 write-all 修复成立。

## Completed work

- 新增 focused tests：
  - `test_http_h1chunked`: short writer 完整 chunk framing / terminal chunk、zero-progress `EIOError`
  - `test_http_h1writer`: short writer 完整 header framing、完整 `Content-Length` body、完整 chunked body
- fresh 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_h1chunked clean test`
    - `9/9 passed`
  - `make -C tests/nextpas.core.http/test_http_h1writer clean test`
    - `24/24 passed`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `104/104 passed`
    - heaptrc `0 unfreed memory blocks`

## Next step

- 中文收尾报告里明确：
  - 当前 `epoll` 仍是 phase-1 accept-evented backend
  - 这轮新增并修复的是 H1 response short-write correctness
  - 下一步应继续上移到 transport/session 层的 backpressure / write-timeout / phase-2 runtime
