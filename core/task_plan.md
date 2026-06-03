# Task Plan: http h1 poll-driven phase2 step3

## Goal

把 `nextpas.core.http` 的 H1 poll-driven runtime 再推进一格：

- 把 `WriteTimeout` / `WakeDeadline` 真正接进 poll-driven response drain
- stalled timed drain 到期后要安全关闭，而不是继续卡在旧的 worker-owned blocking path
- 同时守住现有 threaded / epoll HTTP contract

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 审阅 H1 timed drain seam、epoll deadline wake 触发模型、既有 timeout 契约
- [x] 先补 RED：
  - `test_http_server` 证明 `WriteTimeout > 0` 的 poll path 也不能再走 sync `Write`
  - 同时锁定 deadline wake 以 `Advance([], ...)` 的形式收口 stalled drain
- [x] GREEN：
  - poll-driven H1 所有 response drain 都改走 reactor-owned outbound state
  - `WriteTimeout > 0` 会暴露有限 `WakeDeadline`
  - deadline 到期时会安全结束 session，不再做额外写重试
  - keep-alive / follow-up request / epoll backpressure 既有 proof 不回归
- [x] 跑 focused `test_http_server` 与 heaptrc
- [x] 更新 `docs/http/ARCHITECTURE.md`、`docs/http/API_COVERAGE.md`

## Scope

- 这轮只做 H1 poll-driven phase2 的第三格。
- 不改 `nextpas.core.http` public API。
- 不先做 bounded outbound queue / 多响应公平性策略。
- 不先做 benchmark。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- H1 poll path 的 successful response drain 现在统一进入 reactor-owned outbound state。
- `WriteTimeout > 0` 时：
  - completion wake 仍会先尝试一次 nonblocking drain
  - 若 socket `would-block`，则注册 `peWritable`
  - 同时暴露有限 `WakeDeadline`
  - deadline 到期后 session 会安全关闭，不继续消费 follow-up request
- 当前剩余主线进一步收窄为：
  - bounded outbound queue / multi-response ordering 策略
  - 更细粒度的 stalled-peer timing / close-observation characterization
  - 后续 benchmark / 对标 Go/Rust 的性能验证
