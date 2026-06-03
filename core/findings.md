# Findings: http server runtime architecture refinement

## Scope

- 这轮不是继续刷单点 HTTP correctness case。
- 目标是把 `http` / `net.server` 的现代 server runtime 方向写硬，避免后续在
  `threaded`、`epoll`、`kqueue`、`IOCP` 之间重复摇摆。

## Confirmed truths

### 1. 当前方向已经不是“HTTP 自己拥有线程模型”

- `nextpas.core.http.server` 现在是 facade / composition。
- runtime ownership、backend 选择、session context、worker handoff 已经进入
  `nextpas.core.net.server` foundation。
- `TH1ServerConnectionState` 也已经是独立的 per-connection protocol state object。

### 2. 现有选型本身是对的，但文档里原先还少一条关键边界

- 继续保持：
  - public surface：Go-like
  - protocol/runtime split：Tokio / Hyper-like
  - backend policy：libuv-like
- 真正还缺的是：
  - `epoll` / `kqueue` 是 readiness family
  - `IOCP` 是 completion/proactor family
  - 不能把它们写成“都共用同一个伪装后的 readable/writable backend”

### 3. `IOCP` 的风险点在 foundation seam，不在 HTTP facade

- 当前 `ITcpServerPollDrivenSession` 是 readiness-family seam，适合继续服务
  Linux `epoll` 与 future `kqueue`。
- Windows `IOCP` 需要保持同一 public ownership/session/handoff contract，
  但允许 foundation 层补 completion-aware driver 规则。
- 这意味着 future Windows 支持不应把 socket scheduling 分支重新拉回
  `nextpas.core.http`。

### 4. `BaseServer` 路线现在应该视为已被正式排除

- 共享问题确实存在，但共享点是 foundation runtime，而不是大而全继承树。
- 如果现在回退成 `TBaseServer`，会同时扭曲：
  - protocol/runtime 职责边界
  - readiness/completion backend 语义
  - hijack / pipelining / backpressure 这类协议特有行为

## Verification evidence

- 文档与源码交叉审阅：
  - `docs/http/ARCHITECTURE.md`
  - `docs/net/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
  - `src/nextpas.core.net.server.intf.pas`
  - `src/nextpas.core.net.intf.pas`
  - `src/nextpas.core.http.impl.h1.pas`
- 一手资料对照结论：
  - Go `net/http` 提供同步 `ServeHTTP` handler surface
  - Hyper 把一个连接作为由 runtime 驱动的 protocol object
  - libuv 采用 `epoll` / `kqueue` / `IOCP` 的 backend discipline
  - Microsoft 明确 `IOCP` 是 completion-port 模型，不是 readiness poll

## Remaining gaps / risks

- 这轮只收紧了设计，不代表 `kqueue` / `IOCP` 已进入实现。
- 当前 repo 仍只有 `threaded` 与 Linux `epoll` 落地。
- 在真正开始 Windows backend 前，foundation 还需要先补
  completion-aware driver 规则，否则很容易把 `IOCP` 错接成伪 readiness 层。
