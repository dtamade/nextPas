# Findings: nextpas.core.net.server poll-driven session seam

## Scope

- 这轮把 `nextpas.core.net.server` 从“只有 evented accept”的 `epoll`
  backend，推进到“foundation 可直接驱动 poll-driven per-connection session”的最小
  phase-2 seam。
- 目标是先把 runtime contract 与 backend 直驱路径落地，不直接重开
  `nextpas.core.http.impl.h1` 的生产行为。

## Confirmed truths

### 1. foundation 现在已经有 poll-driven session contract

- [src/nextpas.core.net.server.intf.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.intf.pas:1)
  新增：
  - `TTcpServerPollResult = (tsprWait, tsprDone)`
  - `ITcpServerPollDrivenSession`
- 这个 contract 固定了每个连接状态对象对 runtime 的最小承诺：
  - 暴露当前等待的 `PollEvents`
  - 用 `Advance(...)` 消费 readiness 事件
  - 返回下一轮 wait events 与 connection ownership

### 2. runtime 已经把 “create session” 和 “execute session” 分开

- [src/nextpas.core.net.server.runtime.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.runtime.pas:1)
  新增：
  - `TryCreateTcpServerSession(...)`
  - `ExecuteTcpServerSession(...)`
- 这使 backend 不必再被迫只走 `ServeConn` 一条路：
  - 能创建 session 时，backend 可以自己决定是 worker 执行还是 poll-driven 直驱
  - 不能创建 session 时，仍回退到 legacy handler 路径

### 3. Linux `epoll` 已经不再只是 evented accept

- [src/nextpas.core.net.server.epoll.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.epoll.pas:1)
  现在同时支持两条执行路径：
  - blocking / legacy session：accepted connection 仍交给 foundation worker 执行
  - poll-driven session：若 session 实现 `ITcpServerPollDrivenSession`，则直接注册到
    `epoll` 并由 runtime 驱动 `Advance(...)`
- 这意味着 phase-2 不再只是纸面方向，foundation 已经有第一条真正可运行的
  per-connection evented execution seam。

### 4. HTTP 当前真相仍然没有被说过头

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:1)
  本轮没有改生产实现。
- 也就是说：
  - foundation 已具备 poll-driven session seam
  - 但 H1 目前还没有迁移到这条路径
  - 当前 HTTP server 运行真相仍然以 worker-driven session 为主

## Verification evidence

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - 预期拿到本轮最新 proof：
    - threaded backend 对 poll-driven session 仍回退到 `Run`
    - epoll backend 可以直接驱动 poll-driven session
  - 需要以本轮最终 rerun 结果为准
- 既有 fresh 回归：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `111/111 passed`
  - heaptrc：`0 unfreed memory blocks`
  - 证明当前 `net.server` foundation seam 未误伤 HTTP server correctness baseline

## Remaining gaps / risks

- 目前只有 Linux `epoll` 消费了这条 seam；`kqueue` / `IOCP` 还没有 concrete backend。
- `ITcpServerPollDrivenSession` 只是 foundation contract 已落地，不等于 HTTP H1、
  WebSocket、TLS 等真实协议状态对象已经全部迁移。
- `threaded` backend 仍然是 correctness baseline；高并发真实性能要等 H1 poll-driven 化和
  后续 benchmark 才能评估。
