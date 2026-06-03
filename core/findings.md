# Findings: net.server readiness driver extraction step2

## Scope

- 这轮继续留在 `nextpas.core.net.server` foundation。
- 目标是把 poll-driven worker completion bridge / session context wrapper
  从 `epoll` backend 抽回 runtime helper。

## Confirmed truths

### 1. 上一轮只收了 target，还没收 bridge/context glue

- `TTcpServerPollSessionTarget` 已经进入 foundation。
- 但 `epoll` 里仍保留：
  - queued completion wrapper
  - poll worker handoff wrapper
  - poll session context wrapper

### 2. 这三层本质上也是 readiness-family foundation，不是 Linux 专属

- 它们表达的是：
  - worker completion 如何排队回 runtime
  - reactor 如何被唤醒
  - poll-driven session 如何看到 wrapped handoff
- 这些语义 future `kqueue` 同样需要。

### 3. 这轮下沉后，`epoll` 代码边界更干净

- `nextpas.core.net.server.runtime.pas` 现在拥有：
  - `TTcpServerPollQueuedCompletion`
  - `TTcpServerPollWorkerHandoff`
  - `TTcpServerPollSessionContext`
- `nextpas.core.net.server.epoll.pas` 继续只保留 backend-specific 的：
  - pending completion queue 存储
  - wake 调用
  - poller wait / add / modify / remove
  - accept loop

### 4. 现有 HTTP / H1 契约仍保持稳定

- 这轮没有改 public HTTP API，也没有改 H1 行为语义。
- focused tests 证明：
  - epoll poll-driven wakeup 行为未回退
  - H1 poll-driven request handoff / drain / deadline wake / bounded queue 仍成立

## Verification evidence

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `22/22 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `119/119 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- readiness-family 还没继续抽：
  - pending completion queue storage/driver helper
  - poll target registry helper
- `kqueue` backend 还没真正落地到 `net.server`
- `IOCP` completion-aware driver 仍是后续 foundation 任务，不在本轮范围
