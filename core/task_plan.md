# Task Plan: net.server poll-driven deadline wake seam

## Goal

把 `nextpas.core.net.server` 的 poll-driven foundation 再往前推进一格，
作为 `nextpas.core.http` H1 poll-driven runtime 的前置能力：

- 给 poll-driven session 增加可选 deadline wake seam
- 让 epoll backend 不再只能靠 socket readiness / worker completion 唤醒 session
- 为 H1 后续保持 `IdleTimeout/WriteTimeout` 正确性铺路
- 用 focused tests 固定 deadline synthetic re-entry 行为

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `http/net.server` 相关文件
- [x] 审阅 `docs/design-conventions.md`、`docs/http/ARCHITECTURE.md`、
  `docs/net/ARCHITECTURE.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 先看 focused RED：
  - `test_net_server` 新增 deadline wake poll-driven proof
  - RED 先锁到缺少 `ITcpServerPollDrivenSessionWithDeadline`
- [x] GREEN：
  - 新增可选 `ITcpServerPollDrivenSessionWithDeadline`
  - `epoll` runtime 按最近 deadline 缩短 `poller_wait`
  - deadline 到期时用 `Advance([])` synthetic re-entry 重入 poll-driven session
  - 允许 initial `PollEvents=[]` 但有 finite deadline 的 session 合法注册
- [x] 跑 focused `test_net_server` + `test_http_server` 验证与 heaptrc

## Scope

- 这轮只做 foundation timer seam，不直接迁 H1 state machine。
- 不改 `nextpas.core.http` public API。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- foundation 现在能表达：
  “poll-driven session 除了 socket readiness / worker completion，也可以被 deadline 主动唤醒”
- 后续 H1 poll-driven runtime 可以在不丢 `IdleTimeout/WriteTimeout` 语义的前提下继续推进
- 当前剩余主线进一步收窄为：
  - `TH1ServerConnectionState` 真正实现 `ITcpServerPollDrivenSession`
  - handler worker handoff + outbound drain state machine
  - bounded outbound queue / resumable drain
