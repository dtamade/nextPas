# Findings: net.server poll-driven deadline wake seam

## Scope

- 这轮不是直接迁 H1 state machine。
- 这轮先把 `nextpas.core.net.server` 缺失的 poll-driven deadline wake foundation 补齐，
  为 future H1 poll-driven runtime 保住 timeout correctness。

## Confirmed truths

### 1. H1 poll-driven 当前真正缺的不是 wakeup，而是 timer correctness

- `epoll` foundation 之前已经有 worker-completion -> reactor wakeup。
- 但 `platform_poller_wait(..., -1, ...)` 仍是无限等待；
  poll-driven session 没有 socket readiness / worker completion 时，
  runtime 不会主动再进 `Advance(...)`。
- 对 H1 来说，这会直接破坏 future `IdleTimeout/WriteTimeout` contract，
  因为 `TryRead/TryWrite` 只有被调用时才检查 deadline。

### 2. 这轮正确落点是 foundation 可选 deadline seam，不是硬迁 H1

- [src/nextpas.core.net.server.intf.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.intf.pas:47)
  现在新增可选接口：
  `ITcpServerPollDrivenSessionWithDeadline.WakeDeadline: TDeadline`
- 这是 opt-in seam，不破坏已有 poll-driven session contract。
- 因此 protocol session 可以逐步接入 timer wake，而不是一边迁 H1，一边默默丢 timeout 语义。

### 3. epoll runtime 现在会按最近 deadline 缩短 wait，并在到期时 synthetic re-entry

- [src/nextpas.core.net.server.epoll.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.epoll.pas:414)
  现在新增：
  - active poll-target registry
  - nearest-deadline timeout 计算
  - expired-deadline synthetic `HandlePollTarget(..., [])`
- 这条能力与现有 worker-completion wake 是并列 foundation wake source。
- 当前也允许 initial `PollEvents=[]` 但存在 finite wake deadline 的 session 合法注册。

### 4. foundation correctness 现在有 focused proof

- [tests/nextpas.core.net.server/test_net_server/test_net_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.net.server/test_net_server/test_net_server.lpr:1967)
  现在新增 `Epoll server wakes poll-driven session on deadline`：
  - session 先消费一个字节
  - 再返回 `ANextEvents := []` 并 armed deadline
  - reactor 在没有 socket readiness 的情况下按 deadline 重新进入 `Advance([])`
  - response 仍可继续完成

### 5. 这轮让 H1 下一步更清楚了

- 现在继续迁 H1 poll-driven 时，不需要再为了 timeout correctness 回头补 foundation。
- 下一步真正要做的，是让 `TH1ServerConnectionState` 消费：
  - session context / worker handoff
  - outbound buffer / `TryDrainTo`
  - wake deadline seam

## Verification evidence

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `22/22 passed`
  - 新增 proof：
    - epoll poll-driven session 可以按 deadline synthetic re-entry
    - 不依赖 socket readiness 就能重新推进 state machine
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - 验证 epoll backend foundation 变更没有破坏 HTTP contract truth
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- H1 还没有真正迁到 poll-driven session runtime。
- 当前 deadline target registry 仍是线性扫描实现；后续若面向高并发再评估更强的数据结构。
- `TH1ServerConnectionState` 还没消费新的 deadline seam。
