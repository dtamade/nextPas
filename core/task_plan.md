# Task Plan: nextpas.core.http H1 session context bridge

## Goal

把 `nextpas.core.net.server` 已有的 `ITcpServerSessionContext` /
`ITcpServerWorkerHandoff` 真正桥接到 HTTP H1 session 创建链路：

- `http.server` bridge 不再丢掉 foundation context
- H1 transport/session 可以拿到 context，为下一批 poll-driven handler handoff
  和 response drain state machine 铺路

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 http/net 相关文件
- [x] 审阅 `http.server` / `http.intf` / `http.impl.h1` 与当前 H1 runtime 真相
- [x] 先补 RED / proof：
  - injected HTTP transport 的 context-aware session factory 优先于 legacy path
  - H1 transport 暴露 context-aware session factory
- [x] GREEN：
  - 在 `http.intf` / facade 落地 `ITcpServerSessionContext` alias 与
    `IHttpServerSessionFactoryWithContext`
  - 在 `http.server` 让 `THttpConnHandler` 实现 TCP 层
    `ITcpServerSessionFactoryWithContext`
  - 在 `http.impl.h1` 让 H1 transport/session 创建链路接收并保留 context
- [x] 跑 focused `test_http_contract` + `test_http_server` 验证与 heaptrc
- [ ] 更新控制文件 / 文档并 path-limited commit

## Scope

- 这轮只打通 context / worker-handoff bridge，不直接完成 H1 poll-driven runtime。
- 不改 public `IHttpServer` / handler 同步编程模型。
- 不在这批重开 response writer / outbound queue / wakeup path 的生产实现。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- foundation session context 可以到达 H1 session object
- 下一批可以直接在 H1 内消费 `WorkerHandoff`
- 当前未完成主线被进一步收窄为：
  - poll-driven response writer / outbound queue
  - reactor <-> worker completion wakeup
  - `TH1ServerConnectionState` 真正实现 `ITcpServerPollDrivenSession`
