# Task Plan: http h1 outbound production/drain split

## Goal

把 `nextpas.core.http` 的 H1 server runtime 再往前推进一格：

- 先把 response production 与 socket drain 拆开
- handler 保持同步 public contract，不直接碰 public API
- 为后续 poll-driven H1 runtime 准备 internal outbound queue seam
- 用 focused tests 固定当前 safe-close / no-follow-up-consume 契约

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `docs/http/ARCHITECTURE.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 先看未提交 diff 与 focused RED：
  - `test_http_h1writer` 为 outbound buffer 新 seam 补 focused proof
  - `test_http_server` 暴露 real-socket backpressure 与旧 direct-write 断言冲突
- [x] GREEN：
  - 新增 `nextpas.core.http.impl.h1.outbound.pas`
  - `TH1ServerConnectionState` 改成
    “handler 写 outbound buffer -> flush -> drain to socket”
  - committed response exception 路径保留 best-effort drain
  - 调整 server backpressure proof，不再把 handler-return timing 冻结成 public contract
- [x] 跑 focused `test_http_h1writer` + `test_http_server` 验证与 heaptrc

## Scope

- 这轮只做 H1 internal response production/drain split。
- 不扩 `nextpas.core.http` public API。
- 不直接把 H1 迁到 `ITcpServerPollDrivenSession`。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- H1 server response path 现在能表达：
  “handler 先完整生成协议字节，connection state 再负责 socket drain”
- 后续 poll-driven H1 可以直接复用这条 outbound seam
- 当前剩余主线进一步收窄为：
  - bounded outbound queue
  - resumable drain / would-block 语义
  - `TH1ServerConnectionState` 真正迁入 poll-driven runtime
