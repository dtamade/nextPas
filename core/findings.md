# Findings: HTTP server backend contract surfacing batch 6

## Root causes

- `nextpas.core.net.server` 已经有 backend seam，但 `THttpServerOptions` 之前没有
  把这条 seam 暴露给 HTTP public contract。
- 结果是 runtime foundation 虽然已经落地，HTTP public API 却还不能显式表达
  “这个 server 要选择哪个 runtime backend”。
- 这会让 `HttpServer` 的 public surface 与已固定的 runtime architecture 真相脱节。

## Fixed design truth

- `THttpServerOptions` 现在公开拥有 `Backend: TTcpServerBackend`。
- `THttpServerOptions.Default.Backend` 现在锁定为 `TCP_SERVER_BACKEND_THREADED`。
- `THttpServer.Create` 现在会把 `AOptions.Backend` 下沉到
  `nextpas.core.net.server.NewTcpServer(LTcpOptions)`。
- 因此当调用方显式选择尚未实现的 backend 时，会在 HTTP facade 层稳定得到
  `ENotSupportedError`，而不是被静默忽略后继续走 threaded。

## Why this is the right fix

- 这让 HTTP public options 与 runtime architecture 对齐，不再把 backend 选择藏在下层。
- 先把 seam 暴露并锁定 forward 语义，后续 `epoll/kqueue/IOCP` 真正落地时就不需要再改
  `HttpServer` public API。
- 当前先返回 `ENotSupportedError` 也符合 fail-fast 原则，比悄悄回退到 threaded 更可控。
