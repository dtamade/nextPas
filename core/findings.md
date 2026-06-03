# Findings: nextpas.core.net/http server runtime design freeze

## Scope

- 这轮只做设计收口，把 server runtime 方案固定到文件。
- 目标是回答“HTTP server 现在是什么模型、未来怎么演进”，不是重开 correctness 测试批次。

## Confirmed truths

### 1. 现在没有 `BaseServer`，抽象已经落在 `nextpas.core.net.server`

- 抽象核心在：
  - `TTcpServerBackend`
  - `ITcpServer`
  - `ITcpServerSession`
  - `ITcpServerSessionFactoryWithContext`
  - `ITcpServerWorkerHandoff`
- 当前缺的不是再造一个父类，而是：
  - backend provider / registry
  - phase-2 per-connection evented driver
  - `kqueue` / `IOCP` 具体 backend

### 2. 当前 HTTP server 不是“HTTP 自己起线程”，但也还不是完整 event-driven runtime

- `threaded` backend 是 correctness baseline：
  `accept` 后由连接 worker 同步执行 session。
- Linux `epoll` backend 已经落到 phase 1：
  evented listener + `TryAccept`，但连接执行仍是 worker-driven。
- H1 侧已经把单连接协议状态收成 `TH1ServerConnectionState`，
  说明 protocol state 与 runtime entrypoint 的 split 已经成立。

### 3. 最合理的固定选型是混合模型，不是单范式崇拜

- Go 风格用于 public model：
  handler 保持同步、直线型。
- Tokio / Hyper 风格用于 internal ownership split：
  runtime 驱动 session，协议层不拥有线程模型。
- libuv 风格用于 backend discipline：
  Linux = `epoll`，BSD/macOS = `kqueue`，Windows = `IOCP`。

### 4. “从基类 Server 开始”不是最佳落点

共享问题确实在 server runtime 层，但共享的本体是：

- listen / accept
- backend 选择
- connection ownership
- shutdown
- worker handoff
- cross-platform I/O strategy

这些职责属于 foundation module，而不是协议特定的大继承树。

### 5. 当前真正缺的下一步很具体

- 保持 threaded 与 `epoll` phase-1 的 contract parity
- 设计共享的 phase-2 per-connection evented driver
- 让 `TryRead/TryWrite` 从“预留 seam”变成“真实调度 seam”
- 在此基础上扩 `kqueue` / `IOCP`

## Decisions fixed this round

- `docs/net/ARCHITECTURE.md` 继续作为权威架构文档
- `docs/http/ARCHITECTURE.md` 负责对 HTTP 层解释 runtime ownership
- 不引入大而全的 `TBaseServer`
- 可以存在薄 convenience facade，但不能重新拥有 runtime policy
- benchmark 仍后置；先把 runtime 设计与 correctness contract 分层守住

## Risks / open items

- backend 选择目前仍是 `NewTcpServer(...)` 里的 hardcoded `case`，后续还需要 provider seam
- `epoll` 目前只完成 accept-evented phase 1，不能把它误称为完整版 event-driven HTTP server
- Windows `IOCP` 与 BSD `kqueue` 仍未进入实现，当前只是架构目标，不是已交付能力
