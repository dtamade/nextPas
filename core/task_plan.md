# Task Plan: net.server epoll reactor wakeup seam

## Goal

把 `nextpas.core.net.server` 的 poll-driven foundation 再往前推进一格：

- 给 `platform.io` poller 增加可复用的 wake/drain seam
- 让 Linux `epoll` backend 能把 worker completion 安全送回 reactor 线程
- 允许 poll-driven session 在等待 worker 完成时暂时没有 socket interest
- 为下一批 H1 poll-driven outbound drain / response writer state machine 铺路

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 http/net 相关文件
- [x] 审阅 `docs/net/ARCHITECTURE.md` / `docs/http/ARCHITECTURE.md` 与
  `net.server.epoll` / `platform.io` / `test_net_server` 当前真相
- [x] 先补 RED / proof：
  - `test_platform_io` 锁 `platform_poller_enable_wake / wake / drain_wake`
  - `test_net_server` 锁
    `worker completion -> reactor wakeup -> poll-driven session re-entry`
- [x] GREEN：
  - 在 `platform.io` 落地 Linux `eventfd` wake seam
  - 在 `net.server.epoll` 落地 per-connection context wrapper、
    queued completion、synthetic re-entry
  - 放开 poll-driven session 暂时返回空 socket interest 的合法语义
- [x] 跑 focused `test_platform_io` + `test_net_server` 验证与 heaptrc

## Scope

- 这轮只做 foundation wakeup 基础能力，不直接改 H1 response writer。
- 不改 public `IHttpServer` / `IHttpHandler` 同步编程模型。
- 不扩 HTTP public API，也不引入新的 `BaseServer` 继承层。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- foundation runtime 现在可以安全表达：
  “worker 线程做事，reactor 线程完成协议推进”
- H1 下一批可以直接复用这条 wakeup foundation
- 当前未完成主线被进一步收窄为：
  - H1 outbound queue / resumable drain
  - blocking writer / chunked writer 的 would-block 改造
  - `TH1ServerConnectionState` 真正迁入 poll-driven runtime
