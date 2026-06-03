# Findings: http h1 initial poll-driven bridge

## Scope

- 这轮不是直接做完整 reactor-owned H1 state machine。
- 这轮先让 `TH1ServerConnectionState` 真正实现 `ITcpServerPollDrivenSession`，
  用一条 worker-bridged 路径把 H1 接到 poll-driven foundation 上。

## Confirmed truths

### 1. foundation 已经准备好，但 H1 之前还没真正消费 poll-driven session seam

- `nextpas.core.net.server` 已经具备：
  - poll-driven session seam
  - worker-completion wake
  - deadline wake
- 但 H1 上一轮结束时仍然只有 `ITcpServerSession.Run`，
  还没有真正实现 `ITcpServerPollDrivenSession`。

### 2. 这轮先做 bridge，比直接硬上完整 reactor-owned H1 更稳

- 如果这轮直接把 parser / handler / drain 全部细化成 reactor-owned state machine，
  风险会同时落在：
  - request parse state
  - handler handoff
  - response drain
  - hijack / keep-alive / write-timeout 兼容
- 当前更稳的推进方式是：
  先让 H1 具备 poll-driven session shape，
  并通过 `WorkerHandoff` 把现有整连接 `Run` 安全挂到 worker，
  这样 H1 已经接上正确 foundation seam，同时不破坏现有 HTTP contract。

### 3. H1 session 现在已经暴露 initial poll-driven bridge seam

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:114)
  现在 `TH1ServerConnectionState` 已实现：
  - `ITcpServerSession`
  - `ITcpServerPollDrivenSession`
  - `ITcpServerPollDrivenSessionWithDeadline`
- 当前 bridge 语义是：
  - 初始 `PollEvents = [peReadable]`
  - 第一次 readability 到达后，通过 `WorkerHandoff` 提交整连接 `Run`
  - reactor 侧等待 completion synthetic re-entry
  - completion 后按 ownership 返回结果

### 4. 这轮没有假装“完整 poll-driven H1 已完成”

- 当前 `WakeDeadline` 仍返回 `Infinite`。
- `IH1OutboundBuffer.TryDrainTo` 还没有进入生产路径。
- request parse / response drain / keep-alive loop 仍然由既有 `Run` 负责，
  只是现在它被挂到了 H1 自己暴露的 poll-driven bridge seam 上。

### 5. 这轮对后续真正 H1 phase 2 的价值是真实的

- 现在 epoll backend 已经不再把 H1 视为“只有 blocking session”的黑盒。
- 下一步可以直接在 `TH1ServerConnectionState` 内部逐段替换：
  - 先拆 read/parse
  - 再拆 handler handoff
  - 再拆 outbound drain
- 不需要再回头改 transport factory / foundation session shape。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - 新增 proof：
    - context-aware H1 session 现在暴露 `ITcpServerPollDrivenSession`
  - 现有 epoll HTTP contract proof 未回归：
    - simple GET / keep-alive / pipelining
    - hijack ownership
    - committed-response exception
    - write-timeout / backpressure safe-close
    - malformed chunked ingress / trailers / limits
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- 当前 bridge 还不是 reactor-owned H1 state machine。
- `WakeDeadline` 还没有进入 H1 生产语义。
- `IH1OutboundBuffer.TryDrainTo` 还没被 H1 生产路径消费。
- 整连接 `Run` 仍然是 whole-connection worker execution，性能形态还不是目标终态。
