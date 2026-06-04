# Findings: net.server kqueue backend wiring

## Scope

- 本轮继续留在 `nextpas.core.net.server` foundation 主线。
- 目标不是扩 HTTP public behavior，而是把 `kqueue` 从“底层 wake seam 已备好”
  推进到“backend 命名入口与 facade 注册边界都真实存在”。

## Confirmed truths

### 1. `platform.io` wake seam 补完后，下一刀就应该是 `net.server.kqueue`

- `nextpas.core.net.server.readiness` 已经抽出共用 owner。
- `platform_poller_enable_wake / wake / drain_wake` 在 BSD/macOS 也已落地。
- 如果这时还没有 `nextpas.core.net.server.kqueue` 单元与 builtin registration，
  那 `kqueue` 仍然只是架构意图，不是实际 backend 边界。

### 2. 当前宿主仍然是 Linux，不能伪造 BSD/macOS live truth

- 这轮最诚实的 TDD 形状是：
  - source-contract RED：要求 `nextpas.core.net.server.kqueue.pas` 真存在
  - runtime gate：Linux 上 `kqueue` builtin factory 仍不应误注册
  - HTTP 只补轻量 contract gate，而不是跑重型全量 server suite

### 3. 最合理的实现仍然是薄包装，而不是第二份 owner

- `epoll` 现在已经退成命名包装。
- `kqueue` 的正确落点也应该一样：
  - 单独 unit 保留 backend 名义边界
  - 真实运行 owner 继续复用 `nextpas.core.net.server.readiness`
  - host 差异交给 `platform.io` poller 与 facade registration

### 4. `kqueue` backend wiring 现在已落地

- 新增了 `src/nextpas.core.net.server.kqueue.pas`
- `NewTcpKqueueServer(...)` 现在直接 forward 到 `NewTcpReadinessServer(...)`
- `src/nextpas.core.net.server.pas` 现在会：
  - 在 BSD/macOS 条件下引入 `nextpas.core.net.server.kqueue`
  - 在 BSD/macOS 条件下注册 `tsbKqueue` builtin factory
- Linux 上仍不会误注册 builtin `kqueue` backend

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - 初次失败点：
    - `FAIL: Kqueue backend source contract - source file should exist: /home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.kqueue.pas`
- GREEN:
  - `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `24/24 passed`
  - heaptrc: `0 unfreed memory blocks`
- light HTTP module gate:
  - `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `27/27 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 还没有 BSD/macOS 实机 compile/runtime proof；这仍是 `kqueue` 路线的主缺口。
- `kqueue` backend 目前仍是命名包装，和 `epoll` 一样还没把 H1 全量迁入
  per-connection evented driver。
- Windows `IOCP` completion-family driver 仍是后续 phase，不在本轮范围。
