# Progress Log: nextpas.core.http committed-response exception boundary

## Session

- **Scope:** 锁定 committed response 后的异常路径，避免 server 在同一连接上继续补写 synthetic `500`。
- **Status:** completed

## Current state

- 已确认 backend / architecture truth 已固定在 `docs/http/ARCHITECTURE.md`
  和 `docs/http/README.md`，这轮没有重开 server 模型设计。
- 共享 worktree 仍是脏的；本轮继续只碰 HTTP 相关 tests / 源码 / 控制面。
- committed-response exception seam 已先 RED、后 GREEN 收口。

## Completed work

- 新增 focused tests：
  - `test_http_server`: committed response exception 不追加 `500`
  - `test_http_server`: 同一契约的 epoll differential proof
- 生产修复：
  - `TH1ResponseWriter` 新增内部 committed-state 查询
  - `TH1ServerConnectionState.Run` 现在在 hijack 或 committed response 后异常时都不再补写 `500`
- fresh 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `106/106 passed`
  - `make -C tests/nextpas.core.http/test_http_h1writer clean test`
    - `24/24 passed`
    - heaptrc `0 unfreed memory blocks`

## Next step

- 下一轮应继续 response-side transport/session seam，但不要回到已经修好的 committed-response 分支。
- 优先补：
  - `TBufferedWriter` silent flush-error 的 focused proof
  - write-timeout / zero-progress flush / safe-close 语义
  - 必要时再判断是否要做最小生产修复
