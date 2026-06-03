# Findings: HTTP server runtime foundation planning

## Decision

- 公开 HTTP 使用体验继续保持 Go 风格的同步 handler。
- 内部 server/runtime/protocol 分层改学 Tokio/Hyper。
- 跨平台 backend 纪律改学 libuv：
  - Linux `epoll`
  - macOS / FreeBSD `kqueue`
  - Windows `IOCP`
- 通用 server 基座归属冻结为 `nextpas.core.net.server`，而不是继续由
  `nextpas.core.http.server` 私有化 runtime。

## Why this is the right move

- 当前真正写死线程模型的是 `http.server` 的 accept loop，而不是 HTTP
  public facade 本身。
- `TH1ServerConnectionState` 已经证明协议状态可以开始从线程入口剥离。
- 如果现在继续只修 HTTP 私有 runtime，后面其他 TCP server 还会重复踩一遍。
- 现在最该冻结的是 ownership 和 layering，而不是继续在旧线程模型上做局部优化。

## Fixed plan

- Phase 1: `nextpas.core.net.server` skeleton
- Phase 2: threaded backend first
- Phase 3: HTTP migrate to foundation, behavior unchanged
- Phase 4: Linux `epoll`
- Phase 5: `kqueue`
- Phase 6: Windows `IOCP`
- Phase 7: body streaming / benchmark / performance work
