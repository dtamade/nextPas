# Findings: HTTP server runtime foundation implementation batch 1

## Root cause

- `nextpas.core.http.impl.h1` 原本已经区分“server 继续拥有连接”和“handler
  已 hijack 接管连接”。
- 但 `nextpas.core.net.server.threaded` 新落地后，在 handler 返回时仍无条件
  `Shutdown + Close`，把 hijack 语义踩坏了。
- 这直接表现为 `test_http_server` 的
  `Hijack keeps connection open for handler owner` 回归失败。

## Fixed design truth

- 连接收尾策略必须通过 foundation seam 显式表达，不能再由 threaded runtime
  和具体 protocol transport 各自隐式决定。
- `ITcpServerHandler.ServeConn` 现在返回
  `TTcpServerConnOwnership = (server, handler)`。
- `IHttpServerTransport.ServeConn` 同样返回 post-handler ownership，`THttpServer`
  只负责把这个 ownership 透传给 `ITcpServer` runtime。
- threaded backend 默认仍由 server 收尾；只有 handler 明确接管时才跳过自动关闭。

## Why this is the right fix

- 这把 ownership 语义提升到了可复用的 `net.server` 层，而不是把 hijack 继续做成
  HTTP 私有特例。
- WebSocket / raw socket hijack / 后续其他 TCP 协议 server 都能复用同一条规则。
- 这和已冻结的架构方向一致：runtime 拥有 listener/accept/shutdown/close policy，
  protocol 只返回“当前连接是否已移交”这一事实。
