# Findings: net.server readiness runtime owner extraction

## Scope

- 本轮留在 `nextpas.core.net.server` foundation，并验证 HTTP 不回退。
- 目标不是新增 HTTP 公开功能，而是把 readiness-family runtime owner
  从 `epoll` Linux 专属单元里继续抽离。

## Confirmed truths

### 1. readiness-family 的剩余高价值问题不是“再写一份 kqueue”

- 当前 `epoll` backend 已经大量依赖 `platform_poller_*` 抽象。
- 继续把 owner 留在 `nextpas.core.net.server.epoll`，只会让 future `kqueue`
  再复制一份 listener/poll/completion/deadline 主循环。

### 2. 真正应抽出来的是 readiness runtime owner 本身

- `runtime.pas` 已经拥有 poll target / completion queue / session context 这些底层 helper。
- 但在这轮之前，真正把这些 helper 组合成“可运行 readiness backend”的 owner
  还在 `epoll.pas` 里。
- 这意味着 phase-5 `kqueue` 仍缺一个可复用的共享 owner。

### 3. 这轮最合理的切法是：新增 internal unit，而不是改 public API

- 新增 `nextpas.core.net.server.readiness` 后：
  - `epoll` 可以退成 Linux 命名工厂包装
  - `test_net_server` 可以直接对 shared readiness owner 做 focused proof
  - HTTP facade 与 `ITcpServer` contract 不需要变化

### 4. 这轮已经把 readiness owner 抽实

- `nextpas.core.net.server.readiness.pas` 现在拥有：
  - listener readiness
  - poll-driven session 注册
  - worker-completion -> reactor re-entry
  - deadline wake
  - shutdown wake / fallback self-connect
- `nextpas.core.net.server.epoll.pas` 现在只保留 Linux backend 工厂入口。

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - 先因缺失 `nextpas.core.net.server.readiness` 编译失败
- GREEN:
  - `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `23/23 passed`
  - heaptrc: `0 unfreed memory blocks`
- module gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `173/173 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- `kqueue` backend 还没真正注册/落地。
- BSD/macOS `platform_poller_enable_wake` / `wake` / `drain_wake` 仍未实现，所以
  readiness owner 虽已抽出，但 `kqueue` host wake seam 还差最后一段。
- Windows `IOCP` completion-aware driver 仍是后续 phase，不在本轮范围。
