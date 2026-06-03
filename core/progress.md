# Progress Log: nextpas.core.http H1 session context bridge

## Session

- **Scope:** 把 foundation session context / worker handoff 从
  `nextpas.core.net.server` 真正桥接到 H1 session 创建链路，但不在本轮直接完成
  poll-driven response drain。
- **Status:** in doc-sync / commit-prep

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- HTTP bridge 现在已经不再丢掉 `ITcpServerSessionContext`。
- H1 transport / session 现在可以接住 foundation context。
- H1 poll-driven runtime 仍未落地，当前 worker-driven truth 没有被说过头。

## Completed work

- 审阅并确认当前缺口：
  - TCP runtime 已能传 context
  - HTTP bridge 之前只走 legacy session factory
  - H1 transport 之前没有 context-aware session 创建接口
- 先写 RED：
  - contract proof：context-aware session factory 优先于 legacy path，且可见 worker handoff
  - server proof：H1 transport 暴露 context-aware session factory
- 在 `src/nextpas.core.http.intf.pas` / `src/nextpas.core.http.pas` 落地：
  - `ITcpServerSessionContext` alias
  - `IHttpServerSessionFactoryWithContext`
- 在 `src/nextpas.core.http.server.pas` 落地：
  - `THttpConnHandler` 同时实现
    `ITcpServerSessionFactory` + `ITcpServerSessionFactoryWithContext`
  - 优先转发 transport 的 context-aware session factory
- 在 `src/nextpas.core.http.impl.h1.pas` 落地：
  - `TH1ServerTransport` 实现 `IHttpServerSessionFactoryWithContext`
  - `TH1ServerConnectionState` 保存 `FSessionContext`
- 在 focused tests 落地：
  - `test_http_contract`
  - `test_http_server`

## Verification

- `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `27/27 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 直接进入 H1 poll-driven runtime 真正难点：
  - response writer 改成 outbound queue / drain model
  - handler completion 与 reactor 之间的 wakeup 机制
  - `TH1ServerConnectionState` 实现 `ITcpServerPollDrivenSession`
