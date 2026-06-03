# Findings: net.server readiness driver extraction step1

## Scope

- 这轮不是继续扩 HTTP 语义覆盖。
- 目标是把 readiness-family runtime driver 的最小公共骨架，从
  `nextpas.core.net.server.epoll` 收回到 `nextpas.core.net.server.runtime`。

## Confirmed truths

### 1. 当前最适合先收口的是 readiness-family foundation，不是先空转 `IOCP`

- `platform.io` 已经有 Linux `epoll` 与 BSD/macOS `kqueue` 的 poller 形态。
- 现阶段真正重复风险最高的是：
  - poll-driven session target
  - current-events / wake-deadline bookkeeping
  - runtime seam 检查与 nonblocking 切换
- 所以先把这层收进 foundation，比先空造 Windows-only seam 更稳。

### 2. `epoll` 原先仍保留一块 readiness driver 私有骨架

- `TTcpEpollPollSessionTarget` 原先仍定义在 `nextpas.core.net.server.epoll.pas`。
- 这会让 future `kqueue` 很容易复制一份同构状态壳，而不是复用 foundation helper。

### 3. 这轮下沉后，代码边界更符合已固定的架构文档

- `nextpas.core.net.server.runtime.pas` 现在拥有：
  - `TTcpServerPollSessionTarget`
  - `TryCreateTcpServerPollSessionTarget`
- `nextpas.core.net.server.epoll.pas` 只保留 backend-specific 的：
  - poller wait / add / modify / remove
  - completion queue
  - reactor wake
  - accept loop

### 4. 现有 HTTP contract 没被改动

- 这轮没有改 `IHttpServer`、`IHttpHandler`、H1 parser/writer contract。
- `test_http_server` 全绿证明：
  - epoll backend 行为没回退
  - H1 poll-driven request handoff / drain / deadline wake / bounded queue 语义保持不变

## Verification evidence

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `22/22 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `119/119 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮只抽出了 readiness-family poll-session target/helper，还没继续抽：
  - completion queue/wake wrapper
  - poll-driven session context wrapper
- `kqueue` backend 还没落地到 `net.server`
- `IOCP` completion-aware driver 仍是后续 foundation 任务，不在本轮范围
