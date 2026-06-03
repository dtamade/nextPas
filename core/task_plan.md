# Task Plan: http h1 poll-driven phase2 step2

## Goal

把 `nextpas.core.http` 的 H1 poll-driven runtime 再推进一格：

- successful response 在 poll path 下不再强依赖 worker 内同步 socket write
- reactor 在 completion wake 上先尝试一次 nonblocking drain
- `would-block` 时切到 `peWritable` 继续 drain
- 同时不破坏现有 threaded / epoll HTTP contract，且这批先不动 `WriteTimeout` 的 state machine

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 审阅 H1 poll-driven / outbound / epoll completion wake seam
- [x] 先补 RED：
  - `test_http_server` 证明 poll-driven H1 response drain 不能再走 worker 内同步 `Write`
- [x] GREEN：
  - `TH1ServerConnectionState` 为 poll path 新增 response-drain state
  - completion wake 会先尝试一次 `IH1OutboundBuffer.TryDrainTo`
  - `would-block` 时注册 `peWritable`
  - drain 完成后 keep-alive follow-up request 仍可继续
  - `WriteTimeout > 0` 暂时保留旧的 worker-owned blocking drain，避免半成品 deadline 语义回归
- [x] 跑 focused `test_http_server` 与 heaptrc
- [x] 更新 `docs/http/ARCHITECTURE.md`、`docs/http/API_COVERAGE.md`

## Scope

- 这轮只做 H1 poll-driven phase2 的第二格。
- 不改 `nextpas.core.http` public API。
- 不先把 `WakeDeadline` / `WriteTimeout` 全部接进 H1 生产语义。
- 不先做多响应有界队列 / 更激进 backpressure contract。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- H1 poll path 在 `WriteTimeout = 0` 时，successful response 已经进入 reactor-owned nonblocking drain。
- completion wake 现在不只是等 worker 结果，还会立即尝试一次 drain；
  若 socket 暂时不可写，则转成 `peWritable` 续写。
- keep-alive 快路径仍然保持：
  首个 response 若已 drain 完，缓冲中的 follow-up request 仍可在同一 completion wake 上继续推进。
- 当前剩余主线进一步收窄为：
  - `WriteTimeout` / `WakeDeadline` 真正并入 poll-driven drain
  - timed backpressure close semantics
  - bounded outbound queue / multi-response ordering 策略
