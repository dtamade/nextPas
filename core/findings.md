# Findings: http h1 outbound production/drain split

## Scope

- 这轮不是再扩 malformed chunked ingress coverage。
- 这轮先把 H1 server response path 的“生成响应”与“写 socket”拆开，
  为 future poll-driven H1 铺 internal seam。

## Confirmed truths

### 1. 这轮正确落点不是 public HTTP contract 扩张，而是 H1 internal outbound seam

- `nextpas.core.net.server` 的 context / worker handoff / reactor wakeup 基础已经有了。
- 真正阻塞 H1 继续迁向 poll-driven 的，已经收敛到 response production /
  outbound queue / drain 这条链路。
- 因此这轮正确动作是改 `nextpas.core.http.impl.h1.*`，
  不是再给 facade 加新的 transport/runtime API。

### 2. H1 现在已经落地 internal outbound buffer

- [src/nextpas.core.http.impl.h1.outbound.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.outbound.pas:1)
  新增 `IH1OutboundBuffer` / `TH1OutboundBuffer`：
  - `PendingBytes`
  - `IsEmpty`
  - `DrainAllTo`
  - `TryDrainTo`
  - `Reset`
- 当前 proof 已经锁住：
  - short writer 下 drain-all 仍能完整写完
  - `would-block` 后可以从剩余 offset 继续 drain

### 3. `TH1ServerConnectionState` 现在先生成响应，再统一 drain 到连接

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:447)
  现在改成：
  - per-response 新建 outbound buffer
  - `TH1ResponseWriter` 先写到 buffered writer -> outbound buffer
  - handler 返回后 `Flush`
  - 再由 connection state 把 buffer drain 到 `FConn`
- 这条拆分保住了同步 handler surface，
  同时把真正的 socket write ownership 收回到 connection state。

### 4. real-socket backpressure 的 handler-return timing 不该冻结成 public contract

- 原测试假定 stalled peer 必须在 handler 返回前打断 large streaming response。
- 这在 direct-write 时代成立，但在 response production / drain split 后，
  backpressure 可以发生在 handler 返回之后的 drain 阶段。
- 当前文档里真正要锁的是：
  - safe-close
  - no synthetic `500`
  - no later pipelined request consumption
  - relaxed close-observation truth
- 因此这轮正确修正是调测试契约，不是为了保留旧 timing 断言回退实现。

### 5. 这轮 still-incomplete 的地方也更清楚了

- 当前 outbound buffer 还是 whole-response buffering 中间态。
- 真正高标准终态不应长期停在“无界内存缓冲 + drain all”：
  下一步应收敛到 bounded outbound queue + resumable drain。
- poll-driven H1 需要消费 `TryDrainTo`，而不是把 direct blocking socket write 再塞回 handler。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  - `26/26 passed`
  - 新增 proof：
    - outbound buffer 在 short writer 下完整 drain
    - outbound buffer 在 `would-block` 后可恢复 drain
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - 验证：
    - threaded / epoll real-socket backpressure proof 仍保 safe-close
    - 不追加 synthetic `500`
    - 不消费后续 pipelined request
    - committed response exception / hijack / ingress chunked proofs 未回归
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- outbound buffer 目前没有 backpressure-aware 的容量上界。
- `TH1ServerConnectionState` 还没有真正迁到 poll-driven session runtime。
- `TryDrainTo` 虽已具备 focused proof，但还没被生产路径消费。
